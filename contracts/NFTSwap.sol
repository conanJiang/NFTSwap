// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "./IERC721Receiver.sol";
import "./IERC721.sol";

contract NFTSwap is IERC721Receiver {
    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external override returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }

    //--------------event
    //挂单
    event List(
        address indexed seller,
        address indexed nftAddress,
        uint256 indexed tokenId,
        uint256 price
    );
    //购买
    event Purchase(
        address indexed buyer,
        address indexed nftAddress,
        uint256 indexed tokenId,
        uint256 price
    );
    //撤销
    event Revoke(
        address indexed seller,
        address indexed nftAddress,
        uint256 indexed tokenId
    );
    //更新价格
    event Update(
        address indexed seller,
        address indexed nftAddress,
        uint256 indexed tokenId,
        uint256 newPrice
    );

    //订单
    struct Order {
        address owner;
        uint256 price;
    }
    //挂单信息  结构：nft合约地址 => ( tokenId => Order)
    mapping(address => mapping(uint256 => Order)) public nftList;

    receive() external payable {}

    //挂单
    function list(
        address _nftAddress,
        uint256 _tokenId,
        uint256 _price
    ) public {
        //NFT合约
        IERC721 _nft = IERC721(_nftAddress);
        //判断当前合约是否被授权
        require(_nft.getApproved(_tokenId) == address(this), "Need Approval");
        require(_price > 0, "Price must more than 0");

        Order storage _order = nftList[_nftAddress][_tokenId];
        _order.owner = msg.sender;
        _order.price = _price;
        //将对应的token转账给当前合约
        _nft.safeTransferFrom(msg.sender, address(this), _tokenId);
        //调用事件
        emit List(msg.sender, _nftAddress, _tokenId, _price);
    }

    //撤单 只允许卖家自己撤单
    function revoke(address _nftAddress, uint256 _tokenId) public {
        Order storage _order = nftList[_nftAddress][_tokenId];
        require(_order.owner == msg.sender, "Only owner can revoke");
        IERC721 _nft = IERC721(_nftAddress);

        delete nftList[_nftAddress][_tokenId];

        _nft.safeTransferFrom(address(this), msg.sender, _tokenId);
        emit Revoke(msg.sender, _nftAddress, _tokenId);
    }

    //修改价格 必须是卖家发起
    function update(
        address _nftAddress,
        uint256 _tokenId,
        uint256 _newPrice
    ) public {
        require(_newPrice > 0, "newPrice is invalid");
        Order storage _order = nftList[_nftAddress][_tokenId];
        require(_order.owner == msg.sender, "Only owner can update the price");
        _order.price = _newPrice;
        emit Update(msg.sender, _nftAddress, _tokenId, _newPrice);
    }

    //购买token
    function purchase(address _nftAddress, uint256 _tokenId) public payable {
        Order storage _order = nftList[_nftAddress][_tokenId];
        //token价格必须大于0
        require(_order.price > 0, "Invalid Price");
        //出价必须大于token的价格
        require(msg.value > _order.price, "Increase price");
        IERC721 _nft = IERC721(_nftAddress);
        //当前这个token是否属于当前合约
        require(_nft.ownerOf(_tokenId) == address(this), "Invalid Order");
        //将nft发给买方
        _nft.safeTransferFrom(address(this), msg.sender, _tokenId);
        //将钱发给卖方
        payable(_order.owner).transfer(_order.price);
        payable(msg.sender).transfer(msg.value - _order.price);
        delete nftList[_nftAddress][_tokenId];
        emit Purchase(msg.sender, _nftAddress, _tokenId, _order.price);
    }
}
