// SPDX-License-Identifier: MIT
// Collectify Launchapad Contracts v1.1.0
// Creator: Hging

pragma solidity ^0.8.4;

// import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
// import "./ERC721.sol";
import "./ERC721Enumerable.sol";
import "./IERC721Enumerable.sol";
import "./ERC2981.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

contract OpenEdition is ERC2981, ERC721Enumerable, Ownable {
    uint256 public mintPrice;
    uint256 public fee;
    address public feeAddress;
    uint256 public maxCountPerAddress;
    string public baseURI;
    address public tokenContract;

    address[] private _operatorFilterAddresses;
    
    MintTime public publicMintTime;
    TimeZone public timeZone;

    struct MintTime {
        uint64 startAt;
        uint64 endAt;
    }

    struct TimeZone {
        int8 offset;
        string text;
    }

    struct MintState {
        bool privateMinted;
        bool publicMinted;
    }

    mapping(address => bool) internal publicClaimList;

    constructor(
        string memory name,
        string memory symbol,
        uint256 _mintPrice,
        uint8 _maxCountPerAddress,
        string memory _uri,
        uint96 royaltyFraction,
        TimeZone memory _timezone,
        MintTime memory _publicMintTime,
        address _tokenContract
    ) ERC721(name, symbol) {
        mintPrice = _mintPrice;
        maxCountPerAddress = _maxCountPerAddress;
        baseURI = _uri;
        timeZone = _timezone;
        publicMintTime = _publicMintTime;
        tokenContract = _tokenContract;
        _setDefaultRoyalty(_msgSender(), royaltyFraction);
    }

    modifier onlyAllowedOperatorApproval(address operator) {
        for (uint256 i = 0; i < _operatorFilterAddresses.length; i++) {
            require(
                operator != _operatorFilterAddresses[i],
                "ERC721: operator not allowed"
            );
        }
        _;
    }

    modifier onlyAllowedOperator(address from) {
        for (uint256 i = 0; i < _operatorFilterAddresses.length; i++) {
            require(
                from != _operatorFilterAddresses[i],
                "ERC721: operator not allowed"
            );
        }
        _;
    }

    function _baseURI() internal view virtual override returns (string memory) {
        return baseURI;
    }

    function isMinted(address owner) public view returns (bool) {
        return publicClaimList[owner];
    }

    function changeBaseURI(string memory _uri) public onlyOwner {
        baseURI = _uri;
    }

    function changeMintPrice(uint256 _mintPrice) public onlyOwner {
        mintPrice = _mintPrice;
    }

    function changeFee(uint256 _fee, address _feeAddress) public onlyOwner {
        require(_fee <= mintPrice, "fee is too expensive");
        fee = _fee;
        feeAddress = _feeAddress;
    }

    function changemaxPerAddress(uint8 _maxPerAddress) public onlyOwner {
        maxCountPerAddress = _maxPerAddress;
    }

    function changeDefaultRoyalty(uint96 _royaltyFraction) public onlyOwner {
        _setDefaultRoyalty(_msgSender(), _royaltyFraction);
    }

    function changeRoyalty(uint256 _tokenId, uint96 _royaltyFraction) public onlyOwner {
        _setTokenRoyalty(_tokenId, _msgSender(), _royaltyFraction);
    }

    function changePublicMintTime(MintTime memory _mintTime) public onlyOwner {
        publicMintTime = _mintTime;
    }

    function changeOperatorFilterAddressesAndMintTime(address[] memory _addresses, MintTime memory _mintTime) public onlyOwner {
        _operatorFilterAddresses = _addresses;
        publicMintTime = _mintTime;
    }

    function changeMintTime(MintTime memory _publicMintTime) public onlyOwner {
        publicMintTime = _publicMintTime;
    }

    function operatorFilterAddresses() public view returns (address[] memory) {
        return _operatorFilterAddresses;
    }

    function publicMint(uint256 quantity) external payable {
        require(block.timestamp >= publicMintTime.startAt && block.timestamp <= publicMintTime.endAt, "error: 10000 time is not allowed");
        require(quantity <= maxCountPerAddress, "error: 10004 max per address exceeded");
        uint256 supply = totalSupply();
        address claimAddress = _msgSender();
        require(!publicClaimList[claimAddress], "error:10003 already claimed");
        // _safeMint(claimAddress, quantity);
        if (tokenContract == address(0)) {
            require(mintPrice * quantity <= msg.value, "error: 10002 price insufficient");
            if (fee > 0){
              (bool sent, ) = payable(feeAddress).call{value: fee * quantity}("");
              require(sent, "GG: Failed to transfer fee Ether");
            }
        } else {
            (bool success, bytes memory data) = tokenContract.call(abi.encodeWithSelector(0x23b872dd, claimAddress, address(this), mintPrice * quantity));
            require(
                success && (data.length == 0 || abi.decode(data, (bool))),
                "error: 10002 price insufficient"
            );
            if (fee > 0){
              (bool success2, bytes memory data2) = tokenContract.call(abi.encodeWithSelector(0xa9059cbb, feeAddress, fee * quantity));
              require(
                  success2 && (data2.length == 0 || abi.decode(data, (bool))),
                  "GG: Failed to transfer fee Ether"
              );
            }

        }
        for(uint256 i; i < quantity; i++){
            _safeMint( claimAddress, supply + i );
        }
        publicClaimList[claimAddress] = true;
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(ERC2981, ERC721Enumerable)
        returns (bool)
    {
        // Supports the following `interfaceId`s:
        // - IERC165: 0x01ffc9a7
        // - IERC721: 0x80ac58cd
        // - IERC721Metadata: 0x5b5e139f
        // - IERC2981: 0x2a55205a
        return
            interfaceId == type(IERC721Enumerable).interfaceId ||
            interfaceId == type(IERC721).interfaceId ||
            interfaceId == type(IERC721Metadata).interfaceId ||
            ERC2981.supportsInterface(interfaceId);
    }

    function setApprovalForAll(address operator, bool approved) public override(ERC721, IERC721) onlyAllowedOperatorApproval(operator) {
        super.setApprovalForAll(operator, approved);
    }

    function approve(address operator, uint256 tokenId) public override(ERC721, IERC721) onlyAllowedOperatorApproval(operator) {
        super.approve(operator, tokenId);
    }

    function transferFrom(address from, address to, uint256 tokenId) public override(ERC721, IERC721) onlyAllowedOperator(from) {
        super.transferFrom(from, to, tokenId);
    }

    function safeTransferFrom(address from, address to, uint256 tokenId) public override(ERC721, IERC721) onlyAllowedOperator(from) {
        super.safeTransferFrom(from, to, tokenId);
    }

    function safeTransferFrom(address from, address to, uint256 tokenId, bytes memory data)
        public
        override(ERC721, IERC721)
        onlyAllowedOperator(from)
    {
        super.safeTransferFrom(from, to, tokenId, data);
    }

    // This allows the contract owner to withdraw the funds from the contract.
    function withdraw(uint amt) external onlyOwner {
        if (tokenContract == address(0)) {
            (bool sent, ) = payable(_msgSender()).call{value: amt}("");
            require(sent, "GG: Failed to withdraw Ether");
        } else {
            (bool success, bytes memory data) = tokenContract.call(abi.encodeWithSelector(0xa9059cbb, _msgSender(), amt));
            require(
                success && (data.length == 0 || abi.decode(data, (bool))),
                "GG: Failed to withdraw Ether"
            );
        }

    }
}
