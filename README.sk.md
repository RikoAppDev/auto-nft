[🇺🇸 English](README.md) | [🇸🇰 Slovenský](README.sk.md)

# Blockchain nie je vhodný: Ukladanie zdravotných záznamov

Príklad použitia blockchainu, kde nedáva zmysel, je napríklad ukladanie bežných zdravotných záznamov pacientov do verejného blockchainu. V tomto prípade je problém s ochranou súkromia – zdravotné informácie musia byť prísne chránené a verejný blockchain je zo svojej podstaty transparentný a prístupný každému. Navyše, ak nie je potrebný distribuovaný systém (všetky údaje spravuje jedna nemocnica alebo zdravotná poisťovňa), blockchain len zvyšuje náklady a zložitosť bez pridanej hodnoty.

Ďalším príkladom je projekt Dentacoin, ktorý používa blockchain na evidenciu zubných záznamov a tokenizáciu služieb v stomatológii. V praxi je však pre bežné zubné záznamy blockchain zbytočne komplikovaný a nákladný – postačuje klasická databáza s prístupovými právami.


# Blockchain je vhodný: Tokenizácia áut a servisná história na blockchaine

## Problém

Evidencia vlastníctva áut a ich servisnej histórie je často centralizovaná, neprehľadná a náchylná na manipuláciu. Kupujúci nemajú istotu, že história vozidla je pravdivá a kompletná.


## Vhodnosť blockchainu

Blockchain je vhodný, pretože umožňuje transparentné, nemenné a verejne overiteľné uchovávanie údajov o vlastníctve a histórii áut. VIN číslo auta môže byť tokenizované ako unikátny NFT, pričom všetky servisné záznamy sú navždy uchované a nemožno ich spätne meniť či mazať. Vďaka tomu majiteľ, kupujúci aj servis majú dôveru v pravosť údajov bez potreby dôvery v centrálnu autoritu.


## Architektúra a ďalšie nápady

- **Tokenizácia auta:** Každé auto je reprezentované ako NFT (ERC-721 token) viazaný na VIN číslo.
- **Ukladanie servisnej histórie:** Každý servisný zásah sa pridáva ako záznam k danému NFT.
- **Prevody vlastníctva:** NFT môže byť prevedené na nového majiteľa pri predaji auta.
- **Rozšíriteľnosť:** Možnosť ukladať aj ďalšie dáta – napr. STK kontroly, poistné udalosti, ekologické známky.
- **Prístup:** Len autorizované servisy môžu pridávať servisné záznamy (pomocou role-based access control z OpenZeppelin).
- **Transparentnosť:** Každý si môže overiť históriu auta podľa VIN na blockchaine.
- **Imutabilita:** Údaje nemožno spätne meniť ani mazať.


## Význam riešenia

Tento smart kontrakt umožňuje tokenizovať vozidlo pomocou VIN čísla, prevádzať vlastníctvo auta cez NFT a transparentne uchovávať servisnú históriu. Servisné záznamy môže pridávať iba autorizovaný servis. Všetky údaje sú verejne overiteľné, nemenné a nezávislé od centrálneho správcu. Riešenie je rozšíriteľné o ďalšie typy záznamov (STK, poistenie atď.) a môže výrazne zvýšiť dôveru na trhu s ojazdenými vozidlami.


## Možné ďalšie use-casy

- Ukladanie výsledkov STK a EK kontrol.
- Evidencia poistných udalostí a poistných zmlúv.
- Automatizované preverenie histórie pri predaji auta.
- Prepojenie s IoT zariadeniami v aute pre automatické ukladanie údajov o jazdách a údržbe.


## Solidity smart kontrakt (ukážka, Hardhat/Remix, využíva OpenZeppelin)

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


## Celková Business Logika Kontraktu

### 1. Účel a Hlavné Komponenty  
Kontrakt slúži na **tokenizáciu áut pomocou VIN čísla** a evidenciu **servisnej histórie** na blockchaine. Každé auto je reprezentované ako NFT (ERC-721), pričom servisné záznamy sú nemenné a verejne overiteľné.


### 2. Role a Ich Funkcie  
#### **a) DEFAULT_ADMIN_ROLE**  
- **Kto:** Organizácia/spoločnosť, ktorá kontrakt nasadila (napr. autorizovaná inštitúcia).  
- **Právomoci:**  
  - Registrovať nové autá (`registerCar`).  
  - Prideliť/odobrať `SERVICE_ROLE` servisom (`grantServiceRole`/`revokeServiceRole`).  
  - Pauznúť prevody tokenov (`pause`/`unpause`).  
- **Centralizovaný aspekt:** Správa tejto role je centralizovaná – kontroluje ju jedna entita.  

#### **b) SERVICE_ROLE**  
- **Kto:** Autorizované servisy (napr. partnerské autoservisy).  
- **Právomoci:**  
  - Pridávať servisné záznamy k existujúcim autám (`addServiceRecord`).  
- **Decentralizovaný aspekt:** Viacero nezávislých servisov môže prispievať do histórie.  


### 3. Decentralizácia vs. Centralizácia  
#### **Decentralizované Prvky**  
- **Dáta:** Všetky údaje (VIN, servisná história) sú uložené na verejnom blockchaine – žiadna centrálna autorita ich nemôže meniť.  
- **Overovateľnosť:** Ktokoľvek môže skontrolovať históriu auta bez potreby dôvery v tretiu stranu.  
- **Vlastníctvo:** NFT môže byť voľne prevádzané medzi používateľmi (cez `transferFrom`).  

#### **Centralizované Prvky**  
- **Registrácia áut:** Iba `DEFAULT_ADMIN_ROLE` môže registrovať autá – to zabezpečuje dôveryhodnosť VIN čísla.  
- **Správa servisov:** Admin kontroluje, ktoré servisy môžu pridávať záznamy.  


### 4. Ako to Funguje v Praxi?  
1. **Registrácia auta**  
   - Admin vytvorí NFT pre auto s VIN číslom.  
   - VIN sa ukladá ako `bytes32` hash pre bezpečnosť.  
2. **Servisné záznamy**  
   - Autorizované servisy pridávajú záznamy pri každej údržbe.  
   - Záznamy sú trvalo viazané k NFT auta.  
3. **Predaj auta**  
   - Vlastník prevedie NFT na novú adresu.  
   - História zostáva pripojená k tokenu.  


### 5. Je to Decentralizované?  
- **Áno v:**  
  - Uchovávaní dát (žiadny centrálny úložisko).  
  - Overovaní histórie (transparentnosť).  
- **Nie v:**  
  - Registrácii áut (admin je centrálny bod).  
  - Správe servisných rolí (admin má kontrolu).  


### 6. Odporúčania pre Väčšiu Decentralizáciu  
1. **DAO pre admin rolu:** Namiesto jedného admina použite decentralizovanú autonómnu organizáciu (DAO) na schvaľovanie registrácií.  
2. **Overovanie VIN cez oracles:** Integrujte decentralizované orákulum na overenie platnosti VIN čísla.  
3. **Reputačný systém servisov:** Servisy by získavali oprávnenia na základe hlasovania vlastníkov tokenov.  


## Zhrnutie  
Kontrakt **nie je plne decentralizovaný**, ale kombinuje výhody blockchainu (transparentnosť, nemennosť) s potrebnou kontrolou pre dôveryhodnosť VIN a servisných záznamov. Je vhodný pre:  
- **Dôveryhodné organizácie** (poisťovne, úrady), ktoré chcú digitálne evidovať autá.  
- **Trh s ojazdenými autami**, kde kupujúci potrebujú overiť históriu.  
- **Servisy**, ktoré chcú budovať dôveru cez overiteľné záznamy.  

Decentralizácia je tu obmedzená zámerne – pre konkrétny use case je to optimálny kompromis.  


Transakcia nasadenia kontraktu: [sepolia.etherscan.io](https://sepolia.etherscan.io/tx/0xb9853b44b55f8503b10a21e190e8449bb62daeafdd09fb7471702ff7222cfa1f)