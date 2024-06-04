// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {MerkleProof} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @author gkrastenov
 * @title Airdrop
 * @notice Contract to handle ERC20 token airdrop claims using Merkle proofs.
 */
contract Airdrop is Ownable {
    /// @notice The ERC20 token to be airdropped.
    IERC20 public immutable token;

    /// @notice The timestamp when the redemption period ends.
    IERC20 public immutable reclaimPeriod;

    bytes32 public merkleRoot;
    mapping(bytes32 => bool) public claimed;

    error InvalidInitialization();
    error InvalidProofLength();
    error InvalidProof();
    error CanNotReclaimed();

    event Claimed(address account, uint256 amount);
    event RootUpdated(bytes32 merkleRoot);

    constructor(
        address _token,
        bytes32 _merkleRoot,
        uint256 _reclaimPeriod
    ) Ownable(msg.sender) {
        if (
            _token == address(0) ||
            _merkleRoot == bytes32(0) ||
            _reclaimPeriod == 0
        ) {
            revert InvalidInitialization();
        }

        token = _token;
        merkleRoot = _merkleRoot;
        reclaimPeriod = block.timestamp + _reclaimPeriod;
    }

    /// @notice Sets the Merkle root of the airdrop list.
    function setMerkleRoot(bytes32 _merkleRoot) external onlyOwner {
        merkleRoot = _merkleRoot;
        emit MerkleRootUpdated(_merkleRoot);
    }

    /// @notice Claims the airdrop tokens.
    function claim(
        address _account,
        uint256 _amount,
        bytes32[] memory _proof
    ) external {
        if (_proof.length == 0) revert InvalidProofLength();

        bytes32 leaf = keccak256(abi.encodePacked(_account, _amount));
        if (claimed[leaf]) revert AlreadyClaimed();

        bool verified = MerkleProof.verifyCalldata(_proof, merkleRoot, leaf);
        if (!verified) revert InvalidProof();

        claimed[leaf] = true;

        IERC20(token).safeTransfer(_account, _amount);
        emit Claimed(_account, _amount);
    }

    /// @notice Withdraws the remaining tokens to the owner's address.
    function reclaim(uint256 _amount) external onlyOwner {
        if (block.timestamp < reclaimPeriod) revert CanNotReclaimed();
        IERC20(token).safeTransfer(msg.sender, _amount);
    }
}
