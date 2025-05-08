[🇺🇸 English](README.md) | [🇸🇰 Slovenský](README.sk.md)

# Blockchain Not Suitable: Storing Medical Records

An example where blockchain does not make sense is storing ordinary patient medical records on a public blockchain. In this case, privacy protection is a problem-medical information must be strictly protected, and a public blockchain is by its nature transparent and accessible to everyone. Moreover, if a distributed system is not needed (all data is managed by one hospital or health insurance company), blockchain only increases costs and complexity without added value.

Another example is the Dentacoin project, which uses blockchain to record dental records and tokenize services in dentistry. In practice, however, for ordinary dental records, blockchain is unnecessarily complicated and costly-a classic database with access rights is sufficient.

# Blockchain Suitable: Car Tokenization and Service History on the Blockchain

## Problem
The registration of car ownership and their service history is often centralized, unclear, and prone to manipulation. Buyers cannot be sure that the vehicle's history is truthful and complete.


## Suitability of Blockchain

Blockchain is suitable because it enables transparent, immutable, and publicly verifiable storage of data about car ownership and history. The car's VIN can be tokenized as a unique NFT, and all service records are stored forever and cannot be changed or deleted retroactively. As a result, the owner, buyer, and service center can trust the authenticity of the data without needing to trust a central authority.


## Architecture and Further Ideas

- **Car tokenization:** Each car is represented as an NFT (ERC-721 token) linked to the VIN.
- **Storing service history:** Each service intervention is added as a record to the corresponding NFT.
- **Ownership transfers:** The NFT can be transferred to a new owner when the car is sold.
- **Extensibility:** The possibility to store other data as well-e.g., technical inspections, insurance events, environmental stickers.
- **Access:** Only authorized service centers can add service records (using role-based access control from OpenZeppelin).
- **Transparency:** Anyone can verify the car's history by VIN on the blockchain.
- **Immutability:** Data cannot be changed or deleted retroactively.


## Significance of the Solution

This smart contract allows tokenization of a vehicle using the VIN, transferring car ownership via NFT, and transparently storing service history. Only authorized service centers can add service records. All data is publicly verifiable, immutable, and independent of a central administrator. The solution is extensible to other types of records (technical inspections, insurance, etc.) and can significantly increase trust in the used car market.


## Possible Further Use Cases

- Storing results of technical and emissions inspections.
- Recording insurance events and insurance contracts.
- Automated history verification when selling a car.
- Integration with IoT devices in the car for automatic storage of driving and maintenance data.

## Solidity Smart Contract (example, Hardhat/Remix, uses OpenZeppelin)

```solidity
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
```

## Overall Business Logic of the Contract

### 1. Purpose and Main Components  
The contract serves for **tokenizing cars using the VIN** and recording **service history** on the blockchain. Each car is represented as an NFT (ERC-721), and service records are immutable and publicly verifiable.


### 2. Roles and Their Functions  
#### **a) DEFAULT_ADMIN_ROLE**  
- **Who:** The organization/company that deployed the contract (e.g., an authorized institution).  
- **Powers:**  
  - Register new cars (`registerCar`).  
  - Grant/revoke `SERVICE_ROLE` to service centers (`grantServiceRole`/`revokeServiceRole`).  
  - Pause/unpause token transfers (`pause`/`unpause`).  
- **Centralized aspect:** This role is centralized-managed by a single entity.  

#### **b) SERVICE_ROLE**  
- **Who:** Authorized service centers (e.g., partner garages).  
- **Powers:**  
  - Add service records to existing cars (`addServiceRecord`).  
- **Decentralized aspect:** Multiple independent service centers can contribute to the history.  


### 3. Decentralization vs. Centralization  
#### **Decentralized Elements**  
- **Data:** All data (VIN, service history) is stored on a public blockchain-no central authority can change it.  
- **Verifiability:** Anyone can check the car's history without needing to trust a third party.  
- **Ownership:** NFTs can be freely transferred between users (via `transferFrom`).  

#### **Centralized Elements**  
- **Car registration:** Only `DEFAULT_ADMIN_ROLE` can register cars-required for VIN credibility.  
- **Service center management:** Admin controls which service centers can add records.  


### 4. How Does It Work in Practice?  
1. **Car registration**  
   - Admin creates an NFT for the car with the VIN.  
   - The VIN is stored as a `bytes32` hash for security.  
2. **Service records**  
   - Authorized service centers add records for each maintenance.  
   - Records are permanently linked to the car's NFT.  
3. **Car sale**  
   - The owner transfers the NFT to a new address.  
   - The history remains attached to the token.  


### 5. Is It Decentralized?  
- **Yes in:**  
  - Data storage (no central repository).  
  - History verification (transparency).  
- **No in:**  
  - Car registration (admin is a central point).  
  - Service role management (admin has control).  


### 6. Recommendations for Greater Decentralization  
1. **DAO for admin role:** Instead of a single admin, use a decentralized autonomous organization (DAO) to approve registrations.  
2. **VIN verification via oracles:** Integrate a decentralized oracle to verify VIN validity.  
3. **Service center reputation system:** Service centers could earn permissions based on token holder voting.  


## Summary  
The contract **is not fully decentralized**, but combines the benefits of blockchain (transparency, immutability) with the necessary control for VIN and service record credibility. It is suitable for:  
- **Trusted organizations** (insurance companies, authorities) that want to digitally register cars.  
- **Used car markets**, where buyers need to verify history.  
- **Service centers** that want to build trust through verifiable records.  

Decentralization is intentionally limited here-for this use case, it is the optimal compromise.

Transaction of contract deployment: [sepolia.etherscan.io](https://sepolia.etherscan.io/tx/0xb9853b44b55f8503b10a21e190e8449bb62daeafdd09fb7471702ff7222cfa1f)