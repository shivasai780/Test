// SPDX-License-Identifier: None
pragma solidity ^0.8.11;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";


contract SemiFungable is ERC1155, Ownable {
    using Strings for uint256;

    uint256 private _currentTokenID = 0;
    mapping(uint256 => address) public creators;
    mapping(uint256 => uint256) public tokenSupply;
    // Contract name
    string public name;
    // Contract symbol
    string public symbol;
    // Optional base URI
    string private _baseURI = "";
    //uint public amount=1 ether
    // Optional mapping for token URIs
    mapping(uint256 => string) private _tokenURIs;

    /**
     * @dev Require msg.sender to be the creator of the token id
     */
    modifier creatorOnly(uint256 _id) {
        require(
            creators[_id] == msg.sender,
            "ERC1155Tradable#creatorOnly: ONLY_CREATOR_ALLOWED"
        );
        _;
    }

    /**
     * @dev Require msg.sender to own more than 0 of the token id
     */
    modifier ownersOnly(uint256 _id) {
        require(
            balanceOf(msg.sender, _id)> 0,
            "ERC1155Tradable#ownersOnly: ONLY_OWNERS_ALLOWED"
        );
        _;
    }

    constructor(
        string memory _name,
        string memory _symbol,
        string memory _baseUri
    ) ERC1155("")  {
        name = _name;
        symbol = _symbol;
        _setBaseURI(_baseUri);
    }


    // function totalSupply(uint256 _id) public view returns (uint256) {
    //     return tokenSupply[_id];
    // }

    function create(
        address _initialOwner,
        uint256 _initialSupply,
        string calldata _uri,
        bytes calldata _data//if we are sending the token to some contrcat ,then the to address will be contract ,that contract needs to implemet th eonERC1155function
    ) external onlyOwner returns (uint256) {
        uint256 _id = _getNextTokenID();//get the current token id+1
        _incrementTokenTypeId();//increament the curent token id
        creators[_id] = msg.sender;

        if (bytes(_uri).length > 0) {
            _setURI(_id,_uri);
            emit URI(_uri, _id);
        }

        _mint(_initialOwner, _id, _initialSupply, _data);
        tokenSupply[_id] = _initialSupply;
        return _id;
    }

    function mint(
        address _to,
        uint256 _id,
        uint256 _quantity,
        bytes memory _data
    ) public   creatorOnly(_id) {
        _mint(_to, _id, _quantity, _data);
        tokenSupply[_id] = tokenSupply[_id] + (_quantity);
    }


    function batchMint(
        address _to,
        uint256[] memory _ids,
        uint256[] memory _quantities,
        bytes memory _data
    ) public {
        for (uint256 i = 0; i < _ids.length; i++) {
            uint256 _id = _ids[i];
            require(_exists(_id),"The token id doesn't exist first create it");
            require(
                creators[_id] == msg.sender,
                "ERC1155Tradable#batchMint: ONLY_CREATOR_ALLOWED"
            );
            uint256 quantity = _quantities[i];
            tokenSupply[_id] = tokenSupply[_id] + (quantity);
        }
        _mintBatch(_to, _ids, _quantities, _data);
    }

    function burn(uint256 _id,uint256 _quantity)public {
        require(_exists(_id),"The token id doesn't exist first create it");
        require(balanceOf(msg.sender, _id)>=_quantity,"Quantity exceeds than actual amount");
        require(tokenSupply[_id] >= _quantity,"ERC1155Tradable: burn amount exceeds balance");
        _burn(msg.sender,_id,_quantity);
        tokenSupply[_id]=tokenSupply[_id]-(_quantity);
    }
    function batchBurn(uint256[] memory _ids,
        uint256[] memory _quantities)public{
            for (uint256 i = 0; i < _ids.length; i++) {
            uint256 _id = _ids[i];
            require(_exists(_id),"The token id doesn't exist first create it");
            uint256 quantity = _quantities[i];
            require(tokenSupply[_id]>=quantity,"ERC1155Tradable: burn amount exceeds balance");
            require(
               // creators[_id] == msg.sender,
            //    ownersOnly(_id),
                balanceOf(msg.sender,_id)>=quantity,
                "ERC1155Tradable#batchMint: owner balance exceeds"
            );
            tokenSupply[_id] = tokenSupply[_id] - (quantity);
        }
        _burnBatch(msg.sender, _ids, _quantities);

        }

 
    function setCreator(address _to, uint256[] memory _ids) public {
        require(
            _to != address(0),
            "ERC1155Tradable#setCreator: INVALID_ADDRESS."
        );
        for (uint256 i = 0; i < _ids.length; i++) {
            uint256 id = _ids[i];
            require(_exists(id),"The token id doesn't exist first create it");
            _setCreator(_to, id);
        }
    }


    function _setCreator(address _to, uint256 _id) internal creatorOnly(_id) {
        creators[_id] = _to;
    }

    function _exists(uint256 _id) internal view returns (bool) {
        return creators[_id] != address(0);
    }

    function _getNextTokenID() private view returns (uint256) {
        return _currentTokenID + (1);
    }

    function _incrementTokenTypeId() private {
        _currentTokenID++;
    }


    /**
     * @dev See {IERC1155MetadataURI-uri}.
     *
     * This implementation returns the concatenation of the `_baseURI`
     * and the token-specific uri if the latter is set
     *
     * This enables the following behaviors:
     *
     * - if `_tokenURIs[tokenId]` is set, then the result is the concatenation
     *   of `_baseURI` and `_tokenURIs[tokenId]` (keep in mind that `_baseURI`
     *   is empty per default);
     *
     * - if `_tokenURIs[tokenId]` is NOT set then we fallback to `super.uri()`
     *   which in most cases will contain `ERC1155._uri`;
     *
     * - if `_tokenURIs[tokenId]` is NOT set, and if the parents do not have a
     *   uri value set, then the result is empty.
     */
    function uri(uint256 tokenId)
        public
        view
        virtual
        override
        returns (string memory)
    {
        string memory tokenURI = _tokenURIs[tokenId];

        // If token URI is set, concatenate base URI and tokenURI (via abi.encodePacked).
        return
            bytes(tokenURI).length > 0
                ? string(abi.encodePacked(_baseURI, tokenURI))
                : super.uri(tokenId);
    }

    /**
     * @dev Sets `tokenURI` as the tokenURI of `tokenId`.
     */
    function _setURI(uint256 tokenId, string memory tokenURI) internal virtual {
        _tokenURIs[tokenId] = tokenURI;
        emit URI(uri(tokenId), tokenId);
    }

    /**
     * @dev Sets `baseURI` as the `_baseURI` for all tokens
     */
    function _setBaseURI(string memory baseURI) internal virtual {
        _baseURI = baseURI;
    }

    /*
        function SetAmountByOwner(uint _amount)external onlyOwner{
            require(_amount>0,"Amount cannot be 0");
            amount=_amount;

            } 
    */
}
