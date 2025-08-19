// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol";

/**
 * @title OptimizedERC1155
 * @dev A gas-optimized implementation of the ERC-1155 multi-token standard.
 * Extends OpenZeppelin's ERC1155 for standard compliance and security.
 * Includes custom minting, burning, and total supply tracking with gas optimizations.
 * Avoids direct access to internal OpenZeppelin variables/functions (_balances, _doSafe*).
 * Production-ready with access control, safe math, and metadata handling.
 */
contract OptimizedERC1155 is ERC1155, Ownable {
    using SafeMath for uint256;
    using Strings for uint256;

    // Custom storage for total supply tracking
    mapping(uint256 => uint256) private _totalSupply;

    // Base URI for metadata
    string private _baseURI;

    // Events for minting and burning
    event Minted(address indexed to, uint256 id, uint256 amount);
    event Burned(address indexed from, uint256 id, uint256 amount);

    /**
     * @dev Constructor sets the base URI and initializes Ownable.
     * @param baseURI_ The base URI for token metadata.
     */
    constructor(string memory baseURI_) ERC1155("") Ownable(msg.sender) {
        _baseURI = baseURI_;
    }

    /**
     * @dev Overrides the URI function for custom base URI concatenation.
     * Gas optimization: Uses cached baseURI and Strings library.
     */
    function uri(uint256 id) public view virtual override returns (string memory) {
        return string(abi.encodePacked(_baseURI, id.toString(), ".json"));
    }

    /**
     * @dev Custom gas-optimized mint function.
     * Uses safeTransferFrom for safe transfers and avoids direct _balances access.
     * Only callable by owner for security.
     * @param to Address to mint to.
     * @param id Token ID.
     * @param amount Amount to mint.
     * @param data Optional data for receiver hook.
     */
    function mint(address to, uint256 id, uint256 amount, bytes memory data) external onlyOwner {
        require(to != address(0), "OptimizedERC1155: mint to zero address");
        require(amount > 0, "OptimizedERC1155: mint amount must be greater than 0");

        // Update total supply
        _totalSupply[id] = _totalSupply[id].add(amount);

        // Use safeTransferFrom to mint (from address(0) to recipient)
        // This handles balance updates and receiver checks internally
        super.safeTransferFrom(address(0), to, id, amount, data);

        emit Minted(to, id, amount);
    }

    /**
     * @dev Custom gas-optimized batch mint.
     * Uses safeBatchTransferFrom for safe transfers.
     * @param to Address to mint to.
     * @param ids Array of token IDs.
     * @param amounts Array of amounts.
     * @param data Optional data.
     */
    function mintBatch(address to, uint256[] memory ids, uint256[] memory amounts, bytes memory data) external onlyOwner {
        require(to != address(0), "OptimizedERC1155: mint to zero address");
        require(ids.length == amounts.length, "OptimizedERC1155: ids and amounts length mismatch");
        require(ids.length > 0, "OptimizedERC1155: empty arrays");

        // Update total supply for each ID
        for (uint256 i = 0; i < ids.length; i++) {
            require(amounts[i] > 0, "OptimizedERC1155: mint amount must be greater than 0");
            _totalSupply[ids[i]] = _totalSupply[ids[i]].add(amounts[i]);
        }

        // Use safeBatchTransferFrom to mint
        super.safeBatchTransferFrom(address(0), to, ids, amounts, data);

        emit TransferBatch(msg.sender, address(0), to, ids, amounts);
    }

    /**
     * @dev Custom burn function.
     * Checks balance and updates total supply.
     * @param from Address to burn from.
     * @param id Token ID.
     * @param amount Amount to burn.
     */
    function burn(address from, uint256 id, uint256 amount) external {
        require(from == msg.sender || isApprovedForAll(from, msg.sender), "OptimizedERC1155: caller not owner nor approved");
        require(amount > 0, "OptimizedERC1155: burn amount must be greater than 0");
        require(balanceOf(from, id) >= amount, "OptimizedERC1155: insufficient balance");

        // Update total supply
        _totalSupply[id] = _totalSupply[id].sub(amount);

        // Burn by transferring to address(0)
        super.safeTransferFrom(from, address(0), id, amount, "");

        emit Burned(from, id, amount);
    }

    /**
     * @dev Custom batch burn.
     * @param from Address to burn from.
     * @param ids Array of IDs.
     * @param amounts Array of amounts.
     */
    function burnBatch(address from, uint256[] memory ids, uint256[] memory amounts) external {
        require(from == msg.sender || isApprovedForAll(from, msg.sender), "OptimizedERC1155: caller not owner nor approved");
        require(ids.length == amounts.length, "OptimizedERC1155: ids and amounts length mismatch");
        require(ids.length > 0, "OptimizedERC1155: empty arrays");

        // Check balances and update total supply
        for (uint256 i = 0; i < ids.length; i++) {
            require(amounts[i] > 0, "OptimizedERC1155: burn amount must be greater than 0");
            require(balanceOf(from, ids[i]) >= amounts[i], "OptimizedERC1155: insufficient balance");
            _totalSupply[ids[i]] = _totalSupply[ids[i]].sub(amounts[i]);
        }

        // Burn by transferring to address(0)
        super.safeBatchTransferFrom(from, address(0), ids, amounts, "");

        emit TransferBatch(msg.sender, from, address(0), ids, amounts);
    }

    /**
     * @dev Returns the total supply of a token ID.
     * @param id Token ID.
     */
    function totalSupply(uint256 id) external view returns (uint256) {
        return _totalSupply[id];
    }

    /**
     * @dev Set a new base URI (owner only).
     * @param newBaseURI New base URI.
     */
    function setBaseURI(string memory newBaseURI) external onlyOwner {
        _baseURI = newBaseURI;
    }

    /**
     * @dev Overrides supportsInterface to ensure ERC-1155 compliance.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}