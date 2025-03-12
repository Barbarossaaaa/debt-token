// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IonicDebtToken, ZeroAmount, ZeroAddress, IonTokenNotWhitelisted, TransferFailed, InvalidScaleFactorRange, ZeroDenominator} from "./IonicDebtToken.sol";
import {Test, console2} from "forge-std/Test.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

// Mock contracts for testing
contract MockIonToken is ERC20 {
    address private _underlyingToken;
    uint256 private _exchangeRate;

    constructor(
        string memory name,
        string memory symbol,
        address underlyingToken,
        uint256 exchangeRate
    ) ERC20(name, symbol) {
        _underlyingToken = underlyingToken;
        _exchangeRate = exchangeRate;
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }

    // This function is marked as non-view to match the interface
    // but we implement it as view for testing simplicity
    function exchangeRateCurrent() external view returns (uint256) {
        return _exchangeRate;
    }

    function underlying() external view returns (address) {
        return _underlyingToken;
    }
}

contract MockUnderlyingToken is ERC20 {
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract MockMasterPriceOracle {
    mapping(address => uint256) private prices;

    function setPrice(address token, uint256 priceValue) external {
        prices[token] = priceValue;
    }

    function getUnderlyingPrice(
        address cToken
    ) external view returns (uint256) {
        return prices[cToken];
    }

    function price(address underlying) external view returns (uint256) {
        return prices[underlying];
    }
}

contract IonicDebtTokenTest is Test {
    IonicDebtToken public debtToken;
    MockMasterPriceOracle public oracle;
    MockUnderlyingToken public usdc;
    MockUnderlyingToken public btc;
    MockUnderlyingToken public dai;
    MockIonToken public ionToken;
    MockIonToken public ionBtcToken;

    address public owner = address(1);
    address public user = address(2);

    // For 33.33% value recognition, use 1 as numerator and 3 as denominator
    uint256 public constant SCALE_FACTOR_NUMERATOR = 1;
    uint256 public constant SCALE_FACTOR_DENOMINATOR = 3;

    // Exchange rate 1:5 - each ionToken is worth 1/5 of the underlying token
    // 1e18 represents 1:1, so 1e18/5 represents 1:5
    uint256 public constant EXCHANGE_RATE = 1e18 / 5;

    // Price constants (assuming ETH = $4000)
    // USDC = $2000 = 0.5 ETH
    uint256 public constant USDC_PRICE = 0.5 ether;
    // BTC = $80000 = 20 ETH
    uint256 public constant BTC_PRICE = 20 ether;

    // Add scale factor constant for 98.2%
    uint256 public constant SCALE_FACTOR = 982;

    event TokensMinted(
        address indexed user,
        address indexed ionToken,
        uint256 ionTokenAmount,
        uint256 mintedAmount
    );

    function setUp() public {
        // Deploy mock tokens
        usdc = new MockUnderlyingToken("USDC", "USDC");
        btc = new MockUnderlyingToken("BTC", "BTC");
        dai = new MockUnderlyingToken("DAI", "DAI");

        // Create ion tokens with 5:1 exchange rate
        ionToken = new MockIonToken(
            "Ion USDC",
            "iUSDC",
            address(usdc),
            EXCHANGE_RATE
        );
        ionBtcToken = new MockIonToken(
            "Ion BTC",
            "iBTC",
            address(btc),
            EXCHANGE_RATE
        );

        // Deploy mock oracle
        oracle = new MockMasterPriceOracle();

        // Set prices in the oracle
        oracle.setPrice(address(usdc), USDC_PRICE); // USDC = $2000 (0.5 ETH)
        oracle.setPrice(address(btc), BTC_PRICE); // BTC = $80000 (20 ETH)
        oracle.setPrice(address(dai), 1 ether); // DAI = $4000 (1 ETH)

        // Set up user account
        user = makeAddr("user");
        owner = makeAddr("owner");

        vm.startPrank(owner);
        debtToken = new IonicDebtToken();
        debtToken.initialize(owner, address(oracle), address(usdc));

        // Whitelist both ion tokens with scale factor for 33.33%
        debtToken.whitelistIonToken(
            address(ionToken),
            SCALE_FACTOR_NUMERATOR,
            SCALE_FACTOR_DENOMINATOR
        );
        debtToken.whitelistIonToken(
            address(ionBtcToken),
            SCALE_FACTOR_NUMERATOR,
            SCALE_FACTOR_DENOMINATOR
        );
        vm.stopPrank();

        // Mint tokens to user for testing
        ionToken.mint(user, 1000 * 1e18);
        ionBtcToken.mint(user, 1000 * 1e18);

        // User approves debtToken to transfer their ionTokens
        vm.startPrank(user);
        ionToken.approve(address(debtToken), type(uint256).max);
        ionBtcToken.approve(address(debtToken), type(uint256).max);
        vm.stopPrank();
    }

    // A debug function to trace what's happening in the mint function
    function debugMint(address targetIonToken, uint256 amount) public {
        console2.log("Starting debugMint with amount:", amount);

        // Check if ionToken is whitelisted
        console2.log(
            "Is whitelisted:",
            debtToken.whitelistedIonTokens(targetIonToken)
        );

        // Get scale factor
        (uint256 numerator, uint256 denominator) = debtToken
            .ionTokenScaleFactors(targetIonToken);
        console2.log("Scale factor numerator:", numerator);
        console2.log("Scale factor denominator:", denominator);
        console2.log(
            "This means debt tokens will be worth 33.33% of collateral value"
        );

        // Get exchange rate
        MockIonToken ionTokenContract = MockIonToken(targetIonToken);
        uint256 exchangeRate = ionTokenContract.exchangeRateCurrent();
        console2.log("Exchange rate:", exchangeRate);
        console2.log(
            "Exchange rate is 1:5, meaning each ionToken is worth 1/5 of the underlying token"
        );

        // Calculate underlying amount
        uint256 underlyingAmount = (amount * exchangeRate) / 1e18;
        console2.log("Underlying amount:", underlyingAmount);

        // Get underlying token address
        address underlyingToken = ionTokenContract.underlying();
        console2.log("Underlying token:", underlyingToken);

        // Get prices
        uint256 underlyingPriceInEth = oracle.price(underlyingToken);
        uint256 usdcPriceInEth = oracle.price(address(usdc));
        console2.log("Underlying price in ETH:", underlyingPriceInEth);
        console2.log("USDC price in ETH:", usdcPriceInEth);

        // Calculate USD value
        uint256 underlyingValueInUsd = (underlyingAmount *
            underlyingPriceInEth) / usdcPriceInEth;
        console2.log("Underlying value in USD:", underlyingValueInUsd);

        // Calculate tokens to mint
        uint256 tokensToMint = (underlyingValueInUsd * numerator) / denominator;
        console2.log("Tokens to mint:", tokensToMint);
        console2.log("This is 33.33% of the underlying value");
    }

    // A simple test to verify that a scale factor of 1/3 gives approximately 33.33% of the value
    function test_ScaleFactorOf3GivesApprox33Percent() public {
        uint256 mintAmount = 100 * 1e18;

        // For 33.33% we want numerator = 1, denominator = 3
        uint256 numerator = 1;
        uint256 denominator = 3;
        vm.prank(owner);
        debtToken.updateScaleFactor(address(ionToken), numerator, denominator);

        // Debug the mint function
        debugMint(address(ionToken), mintAmount);

        // Calculate underlying values
        uint256 underlyingAmount = (mintAmount * EXCHANGE_RATE) / 1e18;
        uint256 underlyingValueInUsd = underlyingAmount; // 1:1 price ratio

        // Mint with scale factor
        vm.prank(user);
        debtToken.mint(address(ionToken), mintAmount);

        // Get actual minted amount
        uint256 actualMinted = debtToken.balanceOf(user);

        // Calculate percentage (multiply by 100 for percentage)
        uint256 percent = (actualMinted * 100) / underlyingValueInUsd;

        console2.log("Underlying USD value: ", underlyingValueInUsd);
        console2.log("33.33% of value: ", (underlyingValueInUsd * 33) / 100);
        console2.log("Actual minted: ", actualMinted);
        console2.log("Actual percentage: ", percent);

        // Verify we're getting approximately 33.33% of the underlying value
        assertApproxEqRel(
            percent,
            33,
            0.01e18,
            "Scale factor should give ~33.33% of original value"
        );
    }

    // A test to verify that a scale factor of 1/10 gives approximately 10% of the value
    function test_ScaleFactorOf10GivesApprox10Percent() public {
        uint256 mintAmount = 100 * 1e18;

        // For 10% we want numerator = 1, denominator = 10
        uint256 numerator = 1;
        uint256 denominator = 10;
        vm.prank(owner);
        debtToken.updateScaleFactor(address(ionToken), numerator, denominator);

        // Calculate underlying values
        uint256 underlyingAmount = (mintAmount * EXCHANGE_RATE) / 1e18;
        uint256 underlyingValueInUsd = underlyingAmount; // 1:1 price ratio

        // Calculate expected minted amount with the new scale factor
        uint256 expectedMinted = (underlyingValueInUsd * numerator) /
            denominator;

        console2.log("Underlying USD value: ", underlyingValueInUsd);
        console2.log("Scale factor numerator: ", numerator);
        console2.log("Scale factor denominator: ", denominator);
        console2.log("Expected minted amount: ", expectedMinted);

        // Mint with scale factor
        vm.prank(user);
        debtToken.mint(address(ionToken), mintAmount);

        // Get actual minted amount
        uint256 actualMinted = debtToken.balanceOf(user);
        console2.log("Actual minted: ", actualMinted);

        // Calculate percentage
        uint256 percent = (actualMinted * 100) / underlyingValueInUsd;
        console2.log("Actual percentage: ", percent);

        // Verify we're getting approximately 10% of the underlying value
        assertApproxEqRel(
            percent,
            10,
            0.01e18,
            "Should receive ~10% of the underlying value"
        );
    }

    function test_MintWithValidIonToken() public {
        uint256 mintAmount = 100 * 1e18;

        // Calculate underlying values
        uint256 underlyingAmount = (mintAmount * EXCHANGE_RATE) / 1e18; // 20 USDC
        uint256 underlyingValueInEth = (underlyingAmount * USDC_PRICE) / 1e18; // 10 ETH
        uint256 underlyingValueInUsd = (underlyingValueInEth * 1e18) /
            USDC_PRICE; // Convert back to USD
        uint256 expectedMintedAmount = (underlyingValueInUsd *
            SCALE_FACTOR_NUMERATOR) / SCALE_FACTOR_DENOMINATOR;

        // Log values for verification
        console2.log("Underlying USD value: ", underlyingValueInUsd);
        console2.log("Expected minted amount: ", expectedMintedAmount);

        vm.prank(user);

        // We expect the TokensMinted event to be emitted
        vm.expectEmit(true, true, false, true);
        emit TokensMinted(
            user,
            address(ionToken),
            mintAmount,
            expectedMintedAmount
        );

        debtToken.mint(address(ionToken), mintAmount);

        // Verify the user received the correct amount of debt tokens
        uint256 actualMinted = debtToken.balanceOf(user);
        console2.log("Actual debt tokens received: ", actualMinted);

        // Calculate what would be 33.33% of the underlying value
        uint256 thirtyPercentValue = (underlyingValueInUsd * 33) / 100;
        console2.log(
            "33.33% of underlying value would be: ",
            thirtyPercentValue
        );

        // Verify against the calculated expected amount
        assertEq(
            actualMinted,
            expectedMintedAmount,
            "User should receive the correct amount based on scale factor"
        );

        // Also verify we're getting approximately 33.33% of the underlying value
        uint256 percentReceived = (actualMinted * 100) / underlyingValueInUsd;
        assertApproxEqRel(
            percentReceived,
            33,
            0.01e18,
            "Should receive ~33.33% of the underlying value"
        );

        // Verify the contract received the ionTokens
        assertEq(
            ionToken.balanceOf(address(debtToken)),
            mintAmount,
            "Contract should receive the ionTokens"
        );
    }

    function test_RevertWhenIonTokenNotWhitelisted() public {
        // Deploy a new non-whitelisted ion token
        MockIonToken nonWhitelistedToken = new MockIonToken(
            "ionUSDC",
            "ionUSDC",
            address(usdc),
            EXCHANGE_RATE
        );

        // Mint some tokens to the user
        nonWhitelistedToken.mint(user, 100 * 1e18);

        // Approve spending
        vm.prank(user);
        nonWhitelistedToken.approve(address(debtToken), type(uint256).max);

        // Try to mint with non-whitelisted token, should revert
        vm.prank(user);
        vm.expectRevert(
            abi.encodeWithSelector(
                IonTokenNotWhitelisted.selector,
                address(nonWhitelistedToken)
            )
        );
        debtToken.mint(address(nonWhitelistedToken), 100 * 1e18);
    }

    function test_RevertWhenAmountIsZero() public {
        vm.prank(user);
        vm.expectRevert(ZeroAmount.selector);
        debtToken.mint(address(ionToken), 0);
    }

    function testFuzz_MintWithDifferentAmounts(uint256 mintAmount) public {
        // Ensure amount is reasonable (not zero, not too large)
        vm.assume(mintAmount > 0 && mintAmount <= 1000 * 1e18);

        // Mint more tokens to user for testing
        ionToken.mint(user, 1000 * 1e18);

        // Calculate expected minted amount
        uint256 underlyingAmount = (mintAmount * EXCHANGE_RATE) / 1e18;
        uint256 underlyingValueInEth = (underlyingAmount * USDC_PRICE) / 1e18;
        uint256 underlyingValueInUsd = (underlyingValueInEth * 1e18) /
            USDC_PRICE;
        uint256 expectedMintedAmount = (underlyingValueInUsd *
            SCALE_FACTOR_NUMERATOR) / SCALE_FACTOR_DENOMINATOR;

        vm.prank(user);
        debtToken.mint(address(ionToken), mintAmount);

        // Verify the user received the expected amount, allowing for small rounding errors
        assertApproxEqAbs(
            debtToken.balanceOf(user),
            expectedMintedAmount,
            1, // Allow for a difference of 1 wei due to rounding
            "User should receive the correct amount based on scale factor"
        );

        assertEq(
            ionToken.balanceOf(address(debtToken)),
            mintAmount,
            "Contract should receive the ionTokens"
        );
    }

    function testFuzz_MintWithDifferentScaleFactors(
        uint256 numerator,
        uint256 denominator
    ) public {
        // Ensure scale factor is within valid range (1% to 100%)
        // numerator must be less than or equal to denominator
        numerator = bound(numerator, 1, 100);
        denominator = bound(denominator, numerator, 100);

        // Update the scale factor
        vm.prank(owner);
        debtToken.updateScaleFactor(address(ionToken), numerator, denominator);

        uint256 mintAmount = 100 * 1e18;

        // Calculate expected minted amount with the new scale factor
        uint256 underlyingAmount = (mintAmount * EXCHANGE_RATE) / 1e18;
        uint256 underlyingValueInEth = (underlyingAmount * USDC_PRICE) / 1e18;
        uint256 underlyingValueInUsd = (underlyingValueInEth * 1e18) /
            USDC_PRICE;
        uint256 expectedMintedAmount = (underlyingValueInUsd * numerator) /
            denominator;

        vm.prank(user);
        debtToken.mint(address(ionToken), mintAmount);

        assertEq(
            debtToken.balanceOf(user),
            expectedMintedAmount,
            "User should receive the correct amount of debt tokens"
        );
    }

    // Test scale factor validation
    function test_RevertWhenScaleFactorInvalid() public {
        // Try to set numerator > denominator
        vm.startPrank(owner);
        vm.expectRevert(
            abi.encodeWithSelector(InvalidScaleFactorRange.selector, 11, 10)
        );
        debtToken.whitelistIonToken(address(ionToken), 11, 10);
        vm.stopPrank();
    }

    function test_ValidScaleFactorBoundaries() public {
        // Test minimum valid scale factor (1/100 = 1%)
        uint256 minNumerator = 1;
        uint256 minDenominator = 100;
        vm.prank(owner);
        debtToken.whitelistIonToken(
            address(ionToken),
            minNumerator,
            minDenominator
        );

        // Verify the scale factor was set
        (uint256 numerator, uint256 denominator) = debtToken
            .ionTokenScaleFactors(address(ionToken));
        assertEq(
            numerator,
            minNumerator,
            "Minimum numerator should be accepted"
        );
        assertEq(
            denominator,
            minDenominator,
            "Minimum denominator should be accepted"
        );

        // Test maximum valid scale factor (100/100 = 100%)
        uint256 maxNumerator = 100;
        uint256 maxDenominator = 100;
        vm.prank(owner);
        debtToken.updateScaleFactor(
            address(ionToken),
            maxNumerator,
            maxDenominator
        );

        // Verify the scale factor was updated
        (numerator, denominator) = debtToken.ionTokenScaleFactors(
            address(ionToken)
        );
        assertEq(
            numerator,
            maxNumerator,
            "Maximum numerator should be accepted"
        );
        assertEq(
            denominator,
            maxDenominator,
            "Maximum denominator should be accepted"
        );
    }

    function test_UpdateScaleFactorValidation() public {
        // First whitelist with valid scale factor
        vm.startPrank(owner);
        debtToken.whitelistIonToken(address(ionToken), 50, 100); // 50%

        // Try to update with zero denominator
        uint256 tooLowNumerator = 1;
        uint256 tooLowDenominator = 0;
        vm.expectRevert(ZeroDenominator.selector);
        debtToken.updateScaleFactor(
            address(ionToken),
            tooLowNumerator,
            tooLowDenominator
        );

        // Try to update with numerator > denominator
        uint256 tooHighNumerator = 101;
        uint256 tooHighDenominator = 100;
        vm.expectRevert(
            abi.encodeWithSelector(
                InvalidScaleFactorRange.selector,
                tooHighNumerator,
                tooHighDenominator
            )
        );
        debtToken.updateScaleFactor(
            address(ionToken),
            tooHighNumerator,
            tooHighDenominator
        );
        vm.stopPrank();
    }

    // Test that common percentages work correctly
    function test_CommonPercentages() public {
        uint256[] memory numerators = new uint256[](5);
        uint256[] memory denominators = new uint256[](5);
        uint256[] memory expectedPercentages = new uint256[](5);

        // Set up test cases
        numerators[0] = 100;
        denominators[0] = 100;
        expectedPercentages[0] = 100; // 100%
        numerators[1] = 982;
        denominators[1] = 1000;
        expectedPercentages[1] = 98; // 98.2%
        numerators[2] = 50;
        denominators[2] = 100;
        expectedPercentages[2] = 50; // 50%
        numerators[3] = 25;
        denominators[3] = 100;
        expectedPercentages[3] = 25; // 25%
        numerators[4] = 1;
        denominators[4] = 10;
        expectedPercentages[4] = 10; // 10%

        for (uint256 i = 0; i < numerators.length; i++) {
            vm.prank(owner);
            debtToken.updateScaleFactor(
                address(ionToken),
                numerators[i],
                denominators[i]
            );

            uint256 mintAmount = 100 * 1e18;
            uint256 underlyingAmount = (mintAmount * EXCHANGE_RATE) / 1e18;
            uint256 underlyingValueInUsd = underlyingAmount; // 1:1 price ratio

            vm.prank(user);
            debtToken.mint(address(ionToken), mintAmount);

            uint256 actualMinted = debtToken.balanceOf(user);

            // Calculate actual percentage
            uint256 actualPercent = (actualMinted * 100) / underlyingValueInUsd;

            assertApproxEqRel(
                actualPercent,
                expectedPercentages[i],
                0.01e18,
                string.concat(
                    "Should receive correct percentage for ",
                    vm.toString(expectedPercentages[i]),
                    "%"
                )
            );

            // Reset user balance for next test
            vm.prank(user);
            debtToken.transfer(address(0xdead), actualMinted);
        }
    }

    // Helper function to calculate the expected mint amount
    function calculateExpectedMintAmount(
        uint256 mintAmount
    ) internal view returns (uint256) {
        // Convert ionToken to underlying tokens (1:5 ratio)
        uint256 underlyingAmount = (mintAmount * EXCHANGE_RATE) / 1e18;

        // Get the value in ETH terms
        uint256 underlyingValueInEth = (underlyingAmount * USDC_PRICE) / 1e18;

        // Apply the scale factor (33.33%)
        return
            (underlyingValueInEth * SCALE_FACTOR_NUMERATOR) /
            SCALE_FACTOR_DENOMINATOR;
    }

    // Test that transfer fails
    function test_RevertWhenTransferFails() public {
        // Create a mock token that will fail transfers
        MockFailingIonToken failingToken = new MockFailingIonToken(
            "failToken",
            "FAIL",
            address(dai),
            EXCHANGE_RATE
        );

        // Whitelist the failing token
        vm.prank(owner);
        debtToken.whitelistIonToken(
            address(failingToken),
            SCALE_FACTOR_NUMERATOR,
            SCALE_FACTOR_DENOMINATOR
        );

        // Mint tokens to user
        failingToken.mint(user, 100 * 1e18);

        // Approve spending
        vm.prank(user);
        failingToken.approve(address(debtToken), type(uint256).max);

        // Try to mint, should revert with TransferFailed
        vm.prank(user);
        vm.expectRevert(
            abi.encodeWithSelector(
                TransferFailed.selector,
                address(failingToken),
                user,
                address(debtToken),
                100 * 1e18
            )
        );
        debtToken.mint(address(failingToken), 100 * 1e18);
    }

    // A test to verify that a scale factor of 10183 gives approximately 98.2% of the value
    function test_ScaleFactorFor98Point2Percent() public {
        uint256 mintAmount = 100 * 1e18;

        // Calculate scale factor for 98.2% (982/1000)
        uint256 numerator = 982;
        uint256 denominator = 1000;

        // Calculate underlying values with 1:5 exchange rate
        uint256 underlyingAmount = (mintAmount * EXCHANGE_RATE) / 1e18; // 20 USDC
        uint256 underlyingValueInEth = (underlyingAmount * USDC_PRICE) / 1e18; // 10 ETH
        uint256 underlyingValueInUsd = (underlyingValueInEth * 1e18) /
            USDC_PRICE; // Convert back to USD
        uint256 expectedMinted = (underlyingValueInUsd * numerator) /
            denominator; // 98.2% of value

        // Set scale factor for 98.2%
        vm.prank(owner);
        debtToken.updateScaleFactor(address(ionToken), numerator, denominator);

        // Mint with this scale factor
        vm.prank(user);
        debtToken.mint(address(ionToken), mintAmount);

        // Get actual minted amount
        uint256 actualMinted = debtToken.balanceOf(user);

        // Calculate percentage with 3 decimal precision
        uint256 percent = (actualMinted * 1000) / underlyingValueInUsd;

        console2.log("Underlying amount:", underlyingAmount);
        console2.log("Value in ETH:", underlyingValueInEth);
        console2.log("Value in USD:", underlyingValueInUsd);
        console2.log("Scale factor numerator:", numerator);
        console2.log("Scale factor denominator:", denominator);
        console2.log("Expected minted amount:", expectedMinted);
        console2.log("Actual minted amount:", actualMinted);
        console2.log("Actual percentage (in thousandths):", percent);

        // Should be approximately equal to expected amount
        assertApproxEqRel(
            actualMinted,
            expectedMinted,
            0.001e18,
            "Should receive ~98.2% of the value"
        );
    }

    // Test various granular percentages
    function testFuzz_GranularScaleFactors(uint256 percentage) public {
        // Ensure percentage is between 100 and 10000 (1% to 100% with 2 decimal precision)
        percentage = bound(percentage, 100, 10000);
        console2.log("Testing percentage: ", percentage / 100);

        // Calculate numerator and denominator for the scale factor
        uint256 numerator = percentage;
        uint256 denominator = 10000;

        uint256 mintAmount = 100 * 1e18;

        // Update the scale factor
        vm.prank(owner);
        debtToken.whitelistIonToken(address(ionToken), numerator, denominator);

        // Calculate expected percentage of the underlying value
        uint256 underlyingAmount = (mintAmount * EXCHANGE_RATE) / 1e18;
        uint256 underlyingValueInUsd = (underlyingAmount * BTC_PRICE) /
            BTC_PRICE;
        uint256 expectedMinted = (underlyingValueInUsd * numerator) /
            denominator;

        vm.prank(user);
        debtToken.mint(address(ionToken), mintAmount);

        uint256 actualMinted = debtToken.balanceOf(user);

        console2.log("Numerator: ", numerator);
        console2.log("Denominator: ", denominator);
        console2.log("Expected minted: ", expectedMinted);
        console2.log("Actual minted: ", actualMinted);

        // Allow for some rounding error due to division
        assertApproxEqRel(
            actualMinted,
            expectedMinted,
            0.001e18,
            "Should receive correct percentage of value"
        );
    }

    function test_MintWithRealisticValues() public {
        // Test with USDC first
        uint256 usdcAmount = 1000 * 1e18; // 1000 ionUSDC tokens

        vm.prank(user);
        debtToken.mint(address(ionToken), usdcAmount);

        // Calculate expected USDC value:
        // 1000 ionUSDC * (1/5) (exchange rate) = 200 USDC
        // 200 USDC with price 0.5 ETH = 100 ETH worth of value
        // Convert back to USD value
        uint256 usdcDebtTokens = debtToken.balanceOf(user);

        // Calculate expected value
        uint256 usdcUnderlyingAmount = (usdcAmount * EXCHANGE_RATE) / 1e18; // 200 USDC
        uint256 usdcValueInEth = (usdcUnderlyingAmount * USDC_PRICE) / 1e18;
        uint256 usdcValueInUsd = (usdcValueInEth * 1e18) / USDC_PRICE;
        uint256 expectedUsdcDebtTokens = (usdcValueInUsd *
            SCALE_FACTOR_NUMERATOR) / SCALE_FACTOR_DENOMINATOR;

        assertEq(
            usdcDebtTokens,
            expectedUsdcDebtTokens,
            "Should receive correct amount of debt tokens for USDC"
        );

        // Now test with BTC
        uint256 btcAmount = 10 * 1e18; // 10 ionBTC tokens

        vm.prank(user);
        debtToken.mint(address(ionBtcToken), btcAmount);

        // Calculate expected BTC value:
        // 10 ionBTC * (1/5) (exchange rate) = 2 BTC
        // 2 BTC with price 20 ETH = 40 ETH worth of value
        // Convert back to USD value
        uint256 totalDebtTokens = debtToken.balanceOf(user);
        uint256 btcDebtTokens = totalDebtTokens - usdcDebtTokens;

        // Calculate expected value
        uint256 btcUnderlyingAmount = (btcAmount * EXCHANGE_RATE) / 1e18; // 2 BTC
        uint256 btcValueInEth = (btcUnderlyingAmount * BTC_PRICE) / 1e18;
        uint256 btcValueInUsd = (btcValueInEth * 1e18) / USDC_PRICE;
        uint256 expectedBtcDebtTokens = (btcValueInUsd *
            SCALE_FACTOR_NUMERATOR) / SCALE_FACTOR_DENOMINATOR;

        assertEq(
            btcDebtTokens,
            expectedBtcDebtTokens,
            "Should receive correct amount of debt tokens for BTC"
        );

        // Log the values for verification
        console2.log("USDC Test:");
        console2.log("USDC Underlying Amount:", usdcUnderlyingAmount);
        console2.log("USDC Value in ETH:", usdcValueInEth);
        console2.log("USDC Value in USD:", usdcValueInUsd);
        console2.log("USDC Debt Tokens:", usdcDebtTokens);

        console2.log("\nBTC Test:");
        console2.log("BTC Underlying Amount:", btcUnderlyingAmount);
        console2.log("BTC Value in ETH:", btcValueInEth);
        console2.log("BTC Value in USD:", btcValueInUsd);
        console2.log("BTC Debt Tokens:", btcDebtTokens);
    }
}

// A mock token that always fails on transferFrom
contract MockFailingIonToken is MockIonToken {
    constructor(
        string memory name,
        string memory symbol,
        address underlying,
        uint256 exchangeRate
    ) MockIonToken(name, symbol, underlying, exchangeRate) {}

    function transferFrom(
        address,
        address,
        uint256
    ) public pure override returns (bool) {
        return false;
    }
}
