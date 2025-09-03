// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.19;

import { IHederaTokenService } from "./interfaces/IHederaTokenService.sol";
import { Token } from "../token/Token.sol";

/**
 * @dev Library for Hedera Token Service (HTS) interactions.
 * Provides reusable functions for token association.
 */
library HederaTokenService {
    // HTS precompile address
    address internal constant HTS_ADDRESS = address(0x167);

    // HTS response codes
    int64 internal constant RC_SUCCESS = 22; // Successful token association
    int64 internal constant RC_ALREADY = 194; // Token already associated

    // Error
    error HTSAssociationFailed(int64 responseCode);

    /// @notice Associates tokens to account
    /// @dev Calls associate on token contract, errors with HTSAssociationFailed if association fails
    /// @param account The target of the association
    /// @param tokens The solidity address of the tokens to associate to target
    function safeAssociateTokens(address account, address[] memory tokens) internal {
        // Ignore warning about low-level calls, cause refer from HTS example
        // Refer url: https://github.com/hashgraph/hedera-smart-contracts/blob/583d5fbc916ef43d533f8
        // 99eda6566265343f86e/contracts/system-contracts/hedera-token-service/HederaTokenService.sol
        // solhint-disable-next-line avoid-low-level-calls
        (bool success, bytes memory result) = HTS_ADDRESS.call(
            abi.encodeWithSelector(IHederaTokenService.associateTokens.selector, account, tokens)
        );
        int32 responseCode = success ? abi.decode(result, (int32)) : int32(21); // 21 = unknown

        if (responseCode != RC_SUCCESS && responseCode != RC_ALREADY) {
            revert HTSAssociationFailed(responseCode);
        }
    }

    /// @notice Associates token to account
    /// @dev Calls associate on token contract, errors with HTSAssociationFailed if association fails
    /// @param account The target of the association
    /// @param token The solidity address of the token to associate to target
    function safeAssociateToken(address account, address token) internal {
        // solhint-disable-next-line avoid-low-level-calls
        (bool success, bytes memory result) = HTS_ADDRESS.call(
            abi.encodeWithSelector(IHederaTokenService.associateToken.selector, account, token)
        );
        int32 responseCode = success ? abi.decode(result, (int32)) : int32(21); // 21 = unknown

        if (responseCode != RC_SUCCESS && responseCode != RC_ALREADY) {
            revert HTSAssociationFailed(responseCode);
        }
    }

    /// @notice Checks if an address represents a valid Hedera Token Service (HTS) token
    /// @dev Queries the Hedera Token Service to validate token existence
    ///      This function performs a state-changing call to the precompile
    /// @param token The address to check for HTS token validity
    /// @return true if the address represents a valid HTS token, false otherwise
    function isHTSToken(Token token) internal returns (bool) {
        if (token.isNative()) {
            return false;
        }

        // solhint-disable-next-line avoid-low-level-calls
        (bool success, bytes memory result) = HTS_ADDRESS.call(
            abi.encodeWithSelector(IHederaTokenService.isToken.selector, Token.unwrap(token))
        );

        if (!success) {
            return false;
        }

        (int64 responseCode, bool isToken) = abi.decode(result, (int64, bool));
        return responseCode == RC_SUCCESS && isToken;
    }
}
