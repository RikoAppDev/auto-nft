// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// Import OpenZeppelin libraries for security and standard functionality
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/interfaces/IERC721.sol";

contract CarRegistry is ERC721, AccessControl, Pausable {
    // Define roles
    bytes32 public constant SERVICE_ROLE = keccak256("SERVICE_ROLE");  // Role for authorized service centers

    // Structure for a service record
    struct ServiceRecord {
        uint256 timestamp;      // Timestamp of the record
        string description;     // Description of the service activity
        address serviceCenter;  // Address of the service center
    }

    // Mappings for storing relationships between VIN and tokens
    mapping(bytes32 => uint256) public vinToTokenId;       // Hashed VIN => Token ID
    mapping(uint256 => string) public tokenIdToVin;        // Token ID => VIN (for easy reverse lookup)
    mapping(uint256 => ServiceRecord[]) private serviceHistory; // Service history by token ID
    mapping(uint256 => mapping(bytes32 => bool)) private serviceRecordHashes; // Prevent duplicate service records

    uint256 public nextTokenId = 1;  // Counter for generating unique token IDs

    // Events for tracking important actions
    event CarRegistered(uint256 indexed tokenId, string vin, address indexed owner);
    event ServiceRecordAdded(uint256 indexed tokenId, string description, address indexed serviceCenter);
    
    // Constructor sets up initial parameters
    constructor() ERC721("VehicleNFT", "VHCL") {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);  // Deployer becomes the admin
    }

    // Register a new car (admin only)
    function registerCar(string memory vin, address owner) public onlyRole(DEFAULT_ADMIN_ROLE) {
        require(bytes(vin).length == 17, "Invalid VIN");  // VIN must be 17 characters
        bytes32 vinHash = keccak256(bytes(vin));          // Hash VIN for secure storage
        require(vinToTokenId[vinHash] == 0, "Car already registered"); // Prevent duplicates
        
        uint256 tokenId = nextTokenId++;
        _mint(owner, tokenId);                            // Mint NFT for the owner
        vinToTokenId[vinHash] = tokenId;                  // Store VIN <=> token mapping
        tokenIdToVin[tokenId] = vin;
        emit CarRegistered(tokenId, vin, owner);          // Emit event
    }

    // Add a service record (authorized service centers only)
    function addServiceRecord(string memory vin, string memory description) public onlyRole(SERVICE_ROLE) {
        require(bytes(vin).length == 17, "Invalid VIN");          // Validate VIN
        require(bytes(description).length > 0, "Empty description"); // Validate description
        
        bytes32 vinHash = keccak256(bytes(vin));
        uint256 tokenId = vinToTokenId[vinHash];
        require(tokenId != 0, "Car not registered");      // Ensure car exists

        // Generate a unique hash for the service record to prevent duplicates
        bytes32 recordHash = keccak256(abi.encodePacked(description, block.timestamp));
        require(!serviceRecordHashes[tokenId][recordHash], "Duplicate record");

        // Store the service record
        serviceHistory[tokenId].push(ServiceRecord(
            block.timestamp,
            description,
            msg.sender
        ));
        serviceRecordHashes[tokenId][recordHash] = true;  // Mark record hash as used
        emit ServiceRecordAdded(tokenId, description, msg.sender); // Emit event
    }

    // Retrieve service history with pagination support
    function getServiceHistory(string memory vin, uint256 start, uint256 limit) public view returns (
        uint256[] memory timestamps,
        string[] memory descriptions,
        address[] memory serviceCenters
    ) {
        bytes32 vinHash = keccak256(bytes(vin));
        uint256 tokenId = vinToTokenId[vinHash];
        require(tokenId != 0, "Car not registered");      // Ensure car exists
        
        ServiceRecord[] storage records = serviceHistory[tokenId];
        require(start < records.length, "Start index out of range"); // Validate range

        // Calculate the end index for pagination
        uint256 end = start + limit;
        if (end > records.length) end = records.length;

        // Allocate memory for results
        uint256 resultLength = end - start;
        timestamps = new uint256[](resultLength);
        descriptions = new string[](resultLength);
        serviceCenters = new address[](resultLength);

        // Populate the result arrays
        for(uint256 i = 0; i < resultLength; i++) {
            ServiceRecord storage record = records[start + i];
            timestamps[i] = record.timestamp;
            descriptions[i] = record.description;
            serviceCenters[i] = record.serviceCenter;
        }
    }

    // Role management functions (admin only)
    function grantServiceRole(address account) public onlyRole(DEFAULT_ADMIN_ROLE) {
        grantRole(SERVICE_ROLE, account);  // Grant service role
    }

    function revokeServiceRole(address account) public onlyRole(DEFAULT_ADMIN_ROLE) {
        revokeRole(SERVICE_ROLE, account); // Revoke service role
    }

    // Pause management functions (admin only)
    function pause() public onlyRole(DEFAULT_ADMIN_ROLE) {
        _pause();  // Pause all transfers
    }

    function unpause() public onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause(); // Resume transfers
    }

    // Overridden internal function for transfers with pause support
    function _update(address to, uint256 tokenId, address auth) 
        internal 
        override(ERC721) 
        whenNotPaused 
        returns (address)
    {
        address from = super._update(to, tokenId, auth); // Call original ERC721 logic
        return from;
    }

    // Required function to combine ERC721 and AccessControl interfaces
    function supportsInterface(bytes4 interfaceId) 
        public 
        view 
        override(ERC721, AccessControl) 
        returns (bool) 
    {
        return ERC721.supportsInterface(interfaceId) || AccessControl.supportsInterface(interfaceId);
    }
}
