// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract UniversityCertificateNFT is ERC721URIStorage, Ownable {

    address public hec;

    uint256 public certificateFee = 0 ether;
    uint256 public passingMarks = 50;
    uint256 public certificateCounter;

    constructor(address _hec) Ownable(msg.sender)
        ERC721("University Certificate", "UCERT")
    {
        hec = _hec;
    }

    modifier onlyHEC() {
        require(msg.sender == hec, "Only HEC allowed");
        _;
    }

    enum Status {
        Requested,
        Minted,
        Verified
    }

    struct Certificate {
        address student;
        string studentName;
        string degree;
        uint256 marks;
        bool feePaid;
        Status status;
    }

    // tokenId => Certificate
    mapping(uint256 => Certificate) public certificates;
    

    // -----------------------------
    // Student requests certificate
    // -----------------------------
    function requestCertificate(
        string calldata _studentName,
        string calldata _degree
    ) external payable {
        require(msg.value == certificateFee, "Incorrect fee");

        certificateCounter++;

        certificates[certificateCounter] = Certificate({
            student: msg.sender,
            studentName: _studentName,
            degree: _degree,
            marks: 0,
            feePaid: true,
            status: Status.Requested
        });
    }

    // -----------------------------
    // University sets marks
    // -----------------------------
    function setMarks(
        uint256 _certId,
        uint256 _marks
    ) external onlyOwner {
        require(certificates[_certId].student != address(0), "Invalid cert");
        certificates[_certId].marks = _marks;
    }

    // -----------------------------
    // Mint certificate NFT
    // -----------------------------
    function mintCertificate(
        uint256 _certId,
        string calldata _tokenURI
    ) external onlyOwner {
        Certificate storage cert = certificates[_certId];

        require(cert.status == Status.Requested, "Invalid state");
        require(cert.feePaid, "Fee not paid");
        require(cert.marks >= passingMarks, "Not eligible");

        // Mint NFT to student
        _safeMint(cert.student, _certId);

        // Set metadata (IPFS)
        _setTokenURI(_certId, _tokenURI);

        cert.status = Status.Minted;
    }

    // -----------------------------
    // HEC verifies certificate
    // -----------------------------
    function verifyCertificate(uint256 _certId)
        external
        onlyHEC
    {
        require(certificates[_certId].status == Status.Minted, "Not minted");
        certificates[_certId].status = Status.Verified;
    }

    // -----------------------------
    // Withdraw collected fees
    // -----------------------------
    function withdrawFees() external onlyOwner {
        payable(owner()).transfer(address(this).balance);
    }

    // -----------------------------
    // Public verification helper
    // -----------------------------
    function certificateStatus(uint256 _certId) external view returns (bool) {
        return certificates[_certId].status == Status.Verified;
    }

    function getCertificate(uint256 _certId)
        external
        view
        returns (
            address student,
            string memory name,
            string memory degree,
            Status status
        )
    {
        Certificate memory cert = certificates[_certId];
        return (
            cert.student,
            cert.studentName,
            cert.degree,
            cert.status
        );
    }

}
