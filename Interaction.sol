pragma solidity 0.8.12;
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "hardhat/console.sol";
interface IERC20 {
    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 value
    );
    event Transfer(address indexed from, address indexed to, uint256 value);

    function name() external view returns (string memory);

    function symbol() external view returns (string memory);

    function decimals() external view returns (uint8);

    function totalSupply() external view returns (uint256);

    function balanceOf(address owner) external view returns (uint256);

    function allowance(address owner, address spender)
        external
        view
        returns (uint256);

    function approve(address spender, uint256 value) external returns (bool);

    function transfer(address to, uint256 value) external returns (bool);

    function transferFrom(
        address from,
        address to,
        uint256 value
    ) external returns (bool);

    function mint(address _to, uint256 _amount) external; 
}

contract Interaction is ERC721,Ownable{
    using Strings for uint256;
     using Counters for Counters.Counter; 
    IERC20 public _token;
    uint public TokensforNft;
    uint public Lockingperiod=60 days;
    uint public GrowthNum=1500;
    uint public GrowthDivisor=10000;
    uint public PenalityNum=1000;
    uint public PenalityDivisor=10000;
    mapping(uint256 => string) private _tokenURIs;
    mapping(address=>UserBoxStruct)public UserDetail;
    Counters.Counter private _tokenIds;
    // Base URI
    string private _baseURIextended;
   struct UserBoxStruct{
        uint Balance;
        uint DepositTime;
    }
    
    
    function setBaseURI(string memory baseURI_) external onlyOwner {
        _baseURIextended = baseURI_;
    }
    function _setTokenURI(uint256 tokenId, string memory _tokenURI)
        internal
        virtual
    {
        require(
            _exists(tokenId),
            "ERC721Metadata: URI set of nonexistent token"
        );
        _tokenURIs[tokenId] = _tokenURI;
    }
    function _baseURI() internal view virtual override returns (string memory) {
        return _baseURIextended;
    }
    function tokenURI(uint256 tokenId)
        public
        view
        virtual
        override
        returns (string memory)
    {
        require(
            _exists(tokenId),
            "ERC721Metadata: URI query for nonexistent token"
        );
        string memory _tokenURI = _tokenURIs[tokenId];
        string memory base = _baseURI();
        // If there is no base URI, return the token URI.
        if (bytes(base).length == 0) {
            return _tokenURI;
        }
        // If both are set, concatenate the baseURI and tokenURI (via abi.encodePacked).
        if (bytes(_tokenURI).length > 0) {
            return string(abi.encodePacked(base, _tokenURI));
        }
        // If there is a baseURI but no tokenURI, concatenate the tokenID to the baseURI.
        return string(abi.encodePacked(base, tokenId.toString()));
    }
   
    constructor (string memory _name, string memory _symbol,address _erc20address)Ownable() ERC721(_name, _symbol){
        _token = IERC20(_erc20address);
        SetTokensForNft(100);
    }

    function mint(address _to, string memory tokenURI_)
        internal
        returns (uint256)
    {
        _tokenIds.increment();
        uint256 newItemId = _tokenIds.current();
        _mint(_to, newItemId);
        _setTokenURI(newItemId, tokenURI_);
        return newItemId;
    }
    
    function StakeandgetNFT(uint _amount)external{
        require(_amount == TokensforNft,"The amount that needs to be staked didn't matched");
        require(_token.allowance(msg.sender,address(this)) >= _amount,"No allowance to transfer the token");
        UserBoxStruct storage user = UserDetail[msg.sender];
        require(user.Balance == 0,"you already staked an amount");
        _token.transferFrom(msg.sender, address(this), _amount);
        user.Balance += _amount;
        user.DepositTime = block.timestamp;
        mint(msg.sender, "");
    }

    function Unstake(uint TokenId)external {
        address owner=ERC721.ownerOf(TokenId);
        require(owner == msg.sender,"msg.sender needs to be  the owner");
        UserBoxStruct storage user = UserDetail[msg.sender];
        require(user.Balance >0,"No amount has been staked");
        if(block.timestamp >= (user.DepositTime+Lockingperiod))
        {
            console.log(block.timestamp,"This is the current timestamp");
            console.log((user.DepositTime+Lockingperiod),"This is the total period");
            console.log(Lockingperiod,"Locking Period");
            _burn(TokenId);
            uint growth=(user.Balance*GrowthNum)/GrowthDivisor;
            _token.mint(address(this),growth);
            _token.transfer(msg.sender,(user.Balance+growth));
        }
        else{
            _burn(TokenId);
            uint penality=(user.Balance*PenalityNum)/PenalityDivisor;
            console.log(penality,"penality");
            _token.transfer(msg.sender,(user.Balance-penality));
        }
        user.Balance=0;
    }
    function MintERC20(uint _amount)external onlyOwner{
        uint amounttobeMinted=_amount*(10**18);
        _token.mint(msg.sender,amounttobeMinted);
    }
    function SetTokensForNft(uint _amount)public onlyOwner{
        require(_amount !=0,"amount is not equal to zero");
        TokensforNft=_amount*(10**18);
    }
}
