// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {ERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// Custom Errors for IonicDebtToken contract
error ZeroAddress();
error ZeroAmount();
error ZeroDenominator();
error IonTokenNotWhitelisted(address ionToken);
error TransferFailed(address token, address from, address to, uint256 amount);
error InvalidMasterPriceOracle();
error InvalidUsdcAddress();
error InsufficientBalance(address token, uint256 requested, uint256 available);
error InvalidScaleFactorRange(uint256 numerator, uint256 denominator);

/**
 * @title IonToken Interface
 * @notice Interface for ionTokens (similar to Compound's cTokens)
 */
interface IIonToken is IERC20 {
    function exchangeRateCurrent() external view returns (uint256);

    function underlying() external view returns (address);
}

/**
 * @title MasterPriceOracle Interface
 * @notice Interface for the price oracle that provides price feeds
 */
interface IMasterPriceOracle {
    function getUnderlyingPrice(address cToken) external view returns (uint256);

    function price(address underlying) external view returns (uint256);
}

/**
 * @title IonicDebtToken
 * @notice An ERC20 token that allows users to mint tokens by providing whitelisted ionTokens
 * @dev This contract is upgradeable and ownable
 */
contract IonicDebtToken is
    Initializable,
    ERC20Upgradeable,
    OwnableUpgradeable,
    UUPSUpgradeable
{
    // Struct to store scale factor data
    struct ScaleFactor {
        uint256 numerator;
        uint256 denominator;
    }

    // Address of the MasterPriceOracle contract
    IMasterPriceOracle public masterPriceOracle;

    // Address of USDC token for price conversion
    address public usdcAddress;

    // Mapping of whitelisted ionTokens to their respective scale factors
    mapping(address => ScaleFactor) public ionTokenScaleFactors;

    // Mapping to track if an ionToken is whitelisted
    mapping(address => bool) public whitelistedIonTokens;

    // Event emitted when a new ionToken is whitelisted
    event IonTokenWhitelisted(
        address indexed ionToken,
        uint256 numerator,
        uint256 denominator
    );

    // Event emitted when an ionToken's scale factor is updated
    event ScaleFactorUpdated(
        address indexed ionToken,
        uint256 numerator,
        uint256 denominator
    );

    // Event emitted when tokens are minted
    event TokensMinted(
        address indexed user,
        address indexed ionToken,
        uint256 ionTokenAmount,
        uint256 mintedAmount
    );

    // Event emitted when ionTokens are withdrawn
    event IonTokensWithdrawn(
        address indexed ionToken,
        address indexed recipient,
        uint256 amount
    );

    /**
     * @notice Initializes the contract
     * @param _masterPriceOracle Address of the MasterPriceOracle
     * @param _usdcAddress Address of the USDC token
     */
    function initialize(
        address _owner,
        address _masterPriceOracle,
        address _usdcAddress
    ) public initializer {
        __ERC20_init("IonicDebtToken", "dION");
        __Ownable_init(_owner);
        __UUPSUpgradeable_init();

        if (_masterPriceOracle == address(0)) revert InvalidMasterPriceOracle();
        if (_usdcAddress == address(0)) revert InvalidUsdcAddress();

        masterPriceOracle = IMasterPriceOracle(_masterPriceOracle);
        usdcAddress = _usdcAddress;
    }

    /**
     * @notice Whitelist an ionToken with its scale factor
     * @param ionToken Address of the ionToken to whitelist
     * @param numerator Numerator of the scale factor
     * @param denominator Denominator of the scale factor
     */
    function whitelistIonToken(
        address ionToken,
        uint256 numerator,
        uint256 denominator
    ) external onlyOwner {
        if (ionToken == address(0)) revert ZeroAddress();
        if (denominator == 0) revert ZeroDenominator();
        if (numerator > denominator)
            revert InvalidScaleFactorRange(numerator, denominator);

        whitelistedIonTokens[ionToken] = true;
        ionTokenScaleFactors[ionToken] = ScaleFactor({
            numerator: numerator,
            denominator: denominator
        });

        emit IonTokenWhitelisted(ionToken, numerator, denominator);
    }

    /**
     * @notice Update the scale factor for a whitelisted ionToken
     * @param ionToken Address of the ionToken
     * @param numerator New numerator of the scale factor
     * @param denominator New denominator of the scale factor
     */
    function updateScaleFactor(
        address ionToken,
        uint256 numerator,
        uint256 denominator
    ) external onlyOwner {
        if (!whitelistedIonTokens[ionToken])
            revert IonTokenNotWhitelisted(ionToken);
        if (denominator == 0) revert ZeroDenominator();
        if (numerator > denominator)
            revert InvalidScaleFactorRange(numerator, denominator);

        ionTokenScaleFactors[ionToken] = ScaleFactor({
            numerator: numerator,
            denominator: denominator
        });

        emit ScaleFactorUpdated(ionToken, numerator, denominator);
    }

    /**
     * @notice Remove an ionToken from the whitelist
     * @param ionToken Address of the ionToken to remove
     */
    function removeIonToken(address ionToken) external onlyOwner {
        if (!whitelistedIonTokens[ionToken])
            revert IonTokenNotWhitelisted(ionToken);

        whitelistedIonTokens[ionToken] = false;
        delete ionTokenScaleFactors[ionToken];
    }

    /**
     * @notice Update the MasterPriceOracle address
     * @param _masterPriceOracle New MasterPriceOracle address
     */
    function updateMasterPriceOracle(
        address _masterPriceOracle
    ) external onlyOwner {
        if (_masterPriceOracle == address(0)) revert InvalidMasterPriceOracle();
        masterPriceOracle = IMasterPriceOracle(_masterPriceOracle);
    }

    /**
     * @notice Update the USDC address
     * @param _usdcAddress New USDC address
     */
    function updateUsdcAddress(address _usdcAddress) external onlyOwner {
        if (_usdcAddress == address(0)) revert InvalidUsdcAddress();
        usdcAddress = _usdcAddress;
    }

    /**
     * @notice Preview the amount of dION tokens that would be minted for a given amount of ionTokens
     * @param ionToken Address of the ionToken to check
     * @param amount Amount of ionTokens to simulate
     * @return tokensToMint The amount of dION tokens that would be minted
     */
    function previewMint(address ionToken, uint256 amount) public view returns (uint256 tokensToMint) {
        if (!whitelistedIonTokens[ionToken]) revert IonTokenNotWhitelisted(ionToken);
        if (amount == 0) revert ZeroAmount();

        IIonToken ionTokenContract = IIonToken(ionToken);

        // Get exchange rate from ionToken to underlying
        uint256 exchangeRate = ionTokenContract.exchangeRateCurrent();

        // Calculate underlying amount
        // The exchange rate is scaled by 1e18
        uint256 underlyingAmount = (amount * exchangeRate) / 1e18;

        // Get underlying token address
        address underlyingToken = ionTokenContract.underlying();

        // Get the underlying token price in ETH
        uint256 underlyingPriceInEth = masterPriceOracle.price(underlyingToken);

        // Get USDC price in ETH
        uint256 usdcPriceInEth = masterPriceOracle.price(usdcAddress);

        // Calculate USD value of the underlying tokens
        uint256 underlyingValueInUsd = (underlyingAmount * underlyingPriceInEth) / usdcPriceInEth;

        // Apply scale factor using numerator/denominator
        ScaleFactor memory scaleFactor = ionTokenScaleFactors[ionToken];
        tokensToMint = (underlyingValueInUsd * scaleFactor.numerator) / scaleFactor.denominator;

        return tokensToMint;
    }

    /**
     * @notice Mint dION tokens by providing whitelisted ionTokens
     * @param ionToken Address of the ionToken to provide
     * @param amount Amount of ionTokens to provide
     */
    function mint(address ionToken, uint256 amount) external {
        // Calculate tokens to mint using preview function
        uint256 tokensToMint = previewMint(ionToken, amount);

        // Transfer ionTokens from sender to this contract
        IIonToken ionTokenContract = IIonToken(ionToken);
        bool success = ionTokenContract.transferFrom(
            msg.sender,
            address(this),
            amount
        );
        if (!success)
            revert TransferFailed(ionToken, msg.sender, address(this), amount);

        // Mint dION tokens to the sender
        _mint(msg.sender, tokensToMint);

        emit TokensMinted(msg.sender, ionToken, amount, tokensToMint);
    }

    /**
     * @notice Internal function to handle ionToken withdrawal logic
     * @param ionToken Address of the ionToken to withdraw
     * @param amount Amount of ionTokens to withdraw (0 for all available)
     * @param recipient Address to receive the ionTokens
     */
    function _withdrawIonTokens(
        address ionToken,
        uint256 amount,
        address recipient
    ) internal {
        if (ionToken == address(0)) revert ZeroAddress();
        if (recipient == address(0)) revert ZeroAddress();

        IIonToken ionTokenContract = IIonToken(ionToken);
        uint256 balance = ionTokenContract.balanceOf(address(this));

        // If amount is 0, withdraw the entire balance
        uint256 withdrawAmount = amount == 0 ? balance : amount;

        if (withdrawAmount > balance)
            revert InsufficientBalance(ionToken, withdrawAmount, balance);

        bool success = ionTokenContract.transfer(recipient, withdrawAmount);
        if (!success)
            revert TransferFailed(
                ionToken,
                address(this),
                recipient,
                withdrawAmount
            );

        emit IonTokensWithdrawn(ionToken, recipient, withdrawAmount);
    }

    /**
     * @notice Allows the owner to withdraw collected ionTokens
     * @param ionToken Address of the ionToken to withdraw
     * @param amount Amount of ionTokens to withdraw (0 for all available)
     * @param recipient Address to receive the ionTokens
     */
    function withdrawIonTokens(
        address ionToken,
        uint256 amount,
        address recipient
    ) external onlyOwner {
        _withdrawIonTokens(ionToken, amount, recipient);
    }

    /**
     * @notice Allows the owner to withdraw the entire balance of an ionToken
     * @param ionToken Address of the ionToken to withdraw
     * @param recipient Address to receive the ionTokens
     */
    function withdrawIonTokens(
        address ionToken,
        address recipient
    ) external onlyOwner {
        _withdrawIonTokens(ionToken, 0, recipient);
    }

    /**
     * @notice Required by the UUPS module
     * @dev Only the owner can authorize an upgrade
     */
    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyOwner {}
}
