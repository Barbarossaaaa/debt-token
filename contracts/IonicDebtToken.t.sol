// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IonicDebtToken, ZeroAmount, ZeroAddress, IonTokenNotWhitelisted, TransferFailed, InvalidScaleFactorRange} from "./IonicDebtToken.sol";
import {Test, console2} from "forge-std/Test.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

// Mock contracts for testing
contract MockIonToken is ERC20 {
    address private _underlyingToken;
    uint256 private _exchangeRate;

    constructor(string memory name, string memory symbol, address underlyingToken, uint256 exchangeRate) 
        ERC20(name, symbol) {
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
    constructor(string memory name, string memory symbol) 
        ERC20(name, symbol) {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract MockMasterPriceOracle {
    mapping(address => uint256) private prices;

    function setPrice(address token, uint256 priceValue) external {
        prices[token] = priceValue;
    }

    function getUnderlyingPrice(address cToken) external view returns (uint256) {
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
    MockUnderlyingToken public dai;
    MockIonToken public ionToken;
    
    address public owner = address(1);
    address public user = address(2);
    
    // Scale factor for 98.2% of USD value
    // Using SCALE_PRECISION (10000), for 98.2% we use (10000 * 100) / 982 ≈ 10183
    uint256 public constant SCALE_FACTOR = 10183;
    uint256 public constant EXCHANGE_RATE = 2 * 1e18; // 2:1 exchange rate
    uint256 public constant TOKEN_PRICE = 1000 ether; // 1000 ETH per token
    
    event TokensMinted(
        address indexed user,
        address indexed ionToken,
        uint256 ionTokenAmount,
        uint256 mintedAmount
    );

    function setUp() public {
        // Deploy mock tokens
        dai = new MockUnderlyingToken("DAI", "DAI");
        ionToken = new MockIonToken("Ion Token", "ION", address(dai), EXCHANGE_RATE);
        usdc = new MockUnderlyingToken("USDC", "USDC");
        
        // Deploy mock oracle
        oracle = new MockMasterPriceOracle();
        
        // Set prices in the oracle (1:1 with ETH for simplicity)
        oracle.setPrice(address(usdc), 1e18); // 1 ETH per USDC
        oracle.setPrice(address(dai), 1e18);  // 1 ETH per DAI
        
        // Set up user account
        user = makeAddr("user");
        owner = makeAddr("owner");
        
        vm.startPrank(owner);
        debtToken = new IonicDebtToken();
        debtToken.initialize(owner, address(oracle), address(usdc));
        
        // Whitelist the ionToken with scale factor for 33%
        debtToken.whitelistIonToken(address(ionToken), (debtToken.SCALE_PRECISION() * 100) / 33);
        vm.stopPrank();
        
        // Mint tokens to user for testing
        ionToken.mint(user, 1000 * 1e18);
        
        // User approves debtToken to transfer their ionTokens
        vm.prank(user);
        ionToken.approve(address(debtToken), type(uint256).max);
    }
    
    // A debug function to trace what's happening in the mint function
    function debugMint(address ionToken, uint256 amount) public {
        console2.log("Starting debugMint with amount:", amount);
        
        // Check if ionToken is whitelisted
        console2.log("Is whitelisted:", debtToken.whitelistedIonTokens(ionToken));
        
        // Get scale factor
        uint256 scaleFactor = debtToken.ionTokenScaleFactors(ionToken);
        console2.log("Scale factor:", scaleFactor);
        
        // Get exchange rate
        MockIonToken ionTokenContract = MockIonToken(ionToken);
        uint256 exchangeRate = ionTokenContract.exchangeRateCurrent();
        console2.log("Exchange rate:", exchangeRate);
        
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
        uint256 underlyingValueInUsd = (underlyingAmount * underlyingPriceInEth) / usdcPriceInEth;
        console2.log("Underlying value in USD:", underlyingValueInUsd);
        
        // Calculate tokens to mint
        uint256 tokensToMint = underlyingValueInUsd / scaleFactor;
        console2.log("Tokens to mint:", tokensToMint);
    }
    
    // A simple test to verify that a scale factor of 3 gives approximately 33% of the value
    function test_ScaleFactorOf3GivesApprox33Percent() public {
        uint256 mintAmount = 100 * 1e18;
        
        // For 33.33% we want scaleFactor = (SCALE_PRECISION * 100) / 33
        uint256 scaleFactor = (debtToken.SCALE_PRECISION() * 100) / 33;
        vm.prank(owner);
        debtToken.updateScaleFactor(address(ionToken), scaleFactor);
        
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
        uint256 percent = (actualMinted * 100 * debtToken.SCALE_PRECISION()) / underlyingValueInUsd;
        
        console2.log("Underlying USD value: ", underlyingValueInUsd);
        console2.log("33% of value: ", (underlyingValueInUsd * 33) / 100);
        console2.log("Actual minted: ", actualMinted);
        console2.log("Actual percentage: ", percent);
        
        // Verify we're getting approximately 33% of the underlying value
        assertApproxEqRel(
            percent,
            33,
            0.01e18,
            "Scale factor should give ~33% of original value"
        );
    }
    
    // A test to verify that a scale factor of 10 gives approximately 10% of the value
    function test_ScaleFactorOf10GivesApprox10Percent() public {
        uint256 mintAmount = 100 * 1e18;
        
        // For 10% we want scaleFactor = (SCALE_PRECISION * 100) / 10
        uint256 scaleFactor = (debtToken.SCALE_PRECISION() * 100) / 10;
        vm.prank(owner);
        debtToken.updateScaleFactor(address(ionToken), scaleFactor);
        
        // Calculate underlying values
        uint256 underlyingAmount = (mintAmount * EXCHANGE_RATE) / 1e18;
        uint256 underlyingValueInUsd = underlyingAmount; // 1:1 price ratio
        
        // Calculate expected minted amount
        uint256 expectedMinted = underlyingValueInUsd / scaleFactor;
        
        console2.log("Underlying USD value: ", underlyingValueInUsd);
        console2.log("Scale factor: ", scaleFactor);
        console2.log("Expected minted amount: ", expectedMinted);
        
        // Mint with scale factor
        vm.prank(user);
        debtToken.mint(address(ionToken), mintAmount);
        
        // Get actual minted amount
        uint256 actualMinted = debtToken.balanceOf(user);
        console2.log("Actual minted: ", actualMinted);
        
        // Calculate percentage
        uint256 percent = (actualMinted * 100 * debtToken.SCALE_PRECISION()) / underlyingValueInUsd;
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
        uint256 expectedMintedAmount = calculateExpectedMintAmount(mintAmount);
        
        // Calculate the underlying USD value
        uint256 underlyingAmount = (mintAmount * EXCHANGE_RATE) / 1e18;
        uint256 underlyingValueInUsd = underlyingAmount; // 1:1 price ratio
        
        // Log values for verification
        console2.log("Underlying USD value: ", underlyingValueInUsd);
        console2.log("Expected minted amount: ", expectedMintedAmount);
        
        vm.prank(user);
        
        // We expect the TokensMinted event to be emitted
        vm.expectEmit(true, true, false, true);
        emit TokensMinted(user, address(ionToken), mintAmount, expectedMintedAmount);
        
        debtToken.mint(address(ionToken), mintAmount);
        
        // Verify the user received the correct amount of debt tokens
        uint256 actualMinted = debtToken.balanceOf(user);
        console2.log("Actual debt tokens received: ", actualMinted);
        
        // Calculate what would be 30% of the underlying value
        uint256 thirtyPercentValue = (underlyingValueInUsd * 30) / 100;
        console2.log("30% of underlying value would be: ", thirtyPercentValue);
        
        // Verify against the calculated expected amount
        assertEq(
            actualMinted, 
            expectedMintedAmount, 
            "User should receive the correct amount based on scale factor"
        );
        
        // Also verify we're getting approximately 33% of the underlying value
        uint256 scaleFactor = debtToken.ionTokenScaleFactors(address(ionToken));
        uint256 percentReceived = (actualMinted * 100 * debtToken.SCALE_PRECISION()) / underlyingValueInUsd;
        assertApproxEqRel(percentReceived, 33, 0.01e18, "Should receive ~33% of the underlying value");
        
        // Verify the contract received the ionTokens
        assertEq(ionToken.balanceOf(address(debtToken)), mintAmount, "Contract should receive the ionTokens");
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
        vm.expectRevert(abi.encodeWithSelector(IonTokenNotWhitelisted.selector, address(nonWhitelistedToken)));
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
        
        uint256 expectedMintedAmount = calculateExpectedMintAmount(mintAmount);
        
        vm.prank(user);
        debtToken.mint(address(ionToken), mintAmount);
        
        // Verify the user received the expected amount
        assertEq(
            debtToken.balanceOf(user), 
            expectedMintedAmount, 
            "User should receive the correct amount based on scale factor"
        );
        
        assertEq(ionToken.balanceOf(address(debtToken)), mintAmount, "Contract should receive the ionTokens");
    }
    
    function testFuzz_MintWithDifferentScaleFactors(uint256 scaleFactor) public {
        // Ensure scale factor is within valid range (1% to 100%)
        scaleFactor = bound(scaleFactor, debtToken.SCALE_PRECISION(), debtToken.SCALE_PRECISION() * 100);
        
        // Update the scale factor
        vm.prank(owner);
        debtToken.updateScaleFactor(address(ionToken), scaleFactor);
        
        uint256 mintAmount = 100 * 1e18;
        
        // Calculate expected minted amount with the new scale factor
        uint256 underlyingAmount = (mintAmount * EXCHANGE_RATE) / 1e18;
        uint256 underlyingValueInUsd = (underlyingAmount * TOKEN_PRICE) / TOKEN_PRICE;
        uint256 expectedMintedAmount = underlyingValueInUsd / scaleFactor;
        
        vm.prank(user);
        debtToken.mint(address(ionToken), mintAmount);
        
        assertEq(debtToken.balanceOf(user), expectedMintedAmount, "User should receive the correct amount of debt tokens");
    }
    
    // Test scale factor validation
    function test_RevertWhenScaleFactorTooLow() public {
        uint256 tooLowScaleFactor = debtToken.SCALE_PRECISION() - 1; // Just below minimum
        
        vm.startPrank(owner);
        vm.expectRevert(
            abi.encodeWithSelector(
                InvalidScaleFactorRange.selector,
                tooLowScaleFactor,
                debtToken.SCALE_PRECISION(),
                debtToken.SCALE_PRECISION() * 100
            )
        );
        debtToken.whitelistIonToken(address(ionToken), tooLowScaleFactor);
        vm.stopPrank();
    }

    function test_RevertWhenScaleFactorTooHigh() public {
        uint256 tooHighScaleFactor = debtToken.SCALE_PRECISION() * 100 + 1; // Just above maximum
        
        vm.startPrank(owner);
        vm.expectRevert(
            abi.encodeWithSelector(
                InvalidScaleFactorRange.selector,
                tooHighScaleFactor,
                debtToken.SCALE_PRECISION(),
                debtToken.SCALE_PRECISION() * 100
            )
        );
        debtToken.whitelistIonToken(address(ionToken), tooHighScaleFactor);
        vm.stopPrank();
    }

    function test_ValidScaleFactorBoundaries() public {
        // Test minimum valid scale factor (100%)
        uint256 minScaleFactor = debtToken.SCALE_PRECISION();
        vm.prank(owner);
        debtToken.whitelistIonToken(address(ionToken), minScaleFactor);
        
        // Verify the scale factor was set
        assertEq(
            debtToken.ionTokenScaleFactors(address(ionToken)),
            minScaleFactor,
            "Minimum scale factor should be accepted"
        );

        // Test maximum valid scale factor (1%)
        uint256 maxScaleFactor = debtToken.SCALE_PRECISION() * 100;
        vm.prank(owner);
        debtToken.updateScaleFactor(address(ionToken), maxScaleFactor);
        
        // Verify the scale factor was updated
        assertEq(
            debtToken.ionTokenScaleFactors(address(ionToken)),
            maxScaleFactor,
            "Maximum scale factor should be accepted"
        );
    }

    function test_UpdateScaleFactorValidation() public {
        // First whitelist with valid scale factor
        vm.startPrank(owner);
        debtToken.whitelistIonToken(address(ionToken), debtToken.SCALE_PRECISION() * 2); // 50%
        
        // Try to update with too low scale factor
        uint256 tooLowScaleFactor = debtToken.SCALE_PRECISION() - 1;
        vm.expectRevert(abi.encodeWithSelector(
            InvalidScaleFactorRange.selector,
            tooLowScaleFactor,
            debtToken.SCALE_PRECISION(),
            debtToken.SCALE_PRECISION() * 100
        ));
        debtToken.updateScaleFactor(address(ionToken), tooLowScaleFactor);
        
        // Try to update with too high scale factor
        uint256 tooHighScaleFactor = debtToken.SCALE_PRECISION() * 100 + 1;
        vm.expectRevert(abi.encodeWithSelector(
            InvalidScaleFactorRange.selector,
            tooHighScaleFactor,
            debtToken.SCALE_PRECISION(),
            debtToken.SCALE_PRECISION() * 100
        ));
        debtToken.updateScaleFactor(address(ionToken), tooHighScaleFactor);
        vm.stopPrank();
    }

    // Test that common percentages work correctly
    function test_CommonPercentages() public {
        uint256[] memory percentages = new uint256[](5);
        percentages[0] = 100;  // 100.0%
        percentages[1] = 98;   // 98.2%
        percentages[2] = 50;   // 50.0%
        percentages[3] = 25;   // 25.0%
        percentages[4] = 10;   // 10.0%

        for (uint256 i = 0; i < percentages.length; i++) {
            // Calculate scale factor: (SCALE_PRECISION * 100) / percentage
            uint256 scaleFactor = (debtToken.SCALE_PRECISION() * 100) / percentages[i];
            
            vm.prank(owner);
            debtToken.updateScaleFactor(address(ionToken), scaleFactor);
            
            uint256 mintAmount = 100 * 1e18;
            uint256 underlyingAmount = (mintAmount * EXCHANGE_RATE) / 1e18;
            uint256 underlyingValueInUsd = underlyingAmount; // 1:1 price ratio
            
            vm.prank(user);
            debtToken.mint(address(ionToken), mintAmount);
            
            uint256 actualMinted = debtToken.balanceOf(user);
            
            // Calculate actual percentage
            uint256 actualPercent = (actualMinted * 100 * debtToken.SCALE_PRECISION()) / underlyingValueInUsd;
            
            assertApproxEqRel(
                actualPercent,
                percentages[i],
                0.01e18,
                string.concat("Should receive correct percentage for ", vm.toString(percentages[i]), "%")
            );
            
            // Reset user balance for next test
            vm.prank(user);
            debtToken.transfer(address(0xdead), actualMinted);
        }
    }
    
    // Helper function to calculate the expected mint amount
    function calculateExpectedMintAmount(uint256 mintAmount) internal view returns (uint256) {
        uint256 underlyingAmount = (mintAmount * EXCHANGE_RATE) / 1e18;
        uint256 underlyingValueInUsd = underlyingAmount; // 1:1 price ratio since we set both prices to 1e18
        uint256 scaleFactor = debtToken.ionTokenScaleFactors(address(ionToken));
        return underlyingValueInUsd / scaleFactor;
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
        debtToken.whitelistIonToken(address(failingToken), SCALE_FACTOR);
        
        // Mint tokens to user
        failingToken.mint(user, 100 * 1e18);
        
        // Approve spending
        vm.prank(user);
        failingToken.approve(address(debtToken), type(uint256).max);
        
        // Try to mint, should revert with TransferFailed
        vm.prank(user);
        vm.expectRevert(abi.encodeWithSelector(
            TransferFailed.selector, 
            address(failingToken), 
            user, 
            address(debtToken), 
            100 * 1e18
        ));
        debtToken.mint(address(failingToken), 100 * 1e18);
    }

    // A test to verify that a scale factor of 10183 gives approximately 98.2% of the value
    function test_ScaleFactorFor98Point2Percent() public {
        uint256 mintAmount = 100 * 1e18;
        
        // Calculate scale factor for 98.2% (SCALE_PRECISION * 1000 / 982)
        uint256 scaleFactor = (debtToken.SCALE_PRECISION() * 1000) / 982;
        
        // Calculate underlying values
        uint256 underlyingAmount = (mintAmount * EXCHANGE_RATE) / 1e18;
        uint256 underlyingValueInUsd = (underlyingAmount * TOKEN_PRICE) / TOKEN_PRICE;
        uint256 expectedMinted = underlyingValueInUsd / scaleFactor;
        
        // Set scale factor for 98.2%
        vm.prank(owner);
        debtToken.updateScaleFactor(address(ionToken), scaleFactor);
        
        // Mint with this scale factor
        vm.prank(user);
        debtToken.mint(address(ionToken), mintAmount);
        
        // Get actual minted amount
        uint256 actualMinted = debtToken.balanceOf(user);
        
        // Calculate percentage with 3 decimal precision
        uint256 percent = (actualMinted * 1000) / (underlyingValueInUsd / debtToken.SCALE_PRECISION());
        
        console2.log("Underlying USD value: ", underlyingValueInUsd);
        console2.log("Scale factor: ", scaleFactor);
        console2.log("Expected minted amount: ", expectedMinted);
        console2.log("Actual minted amount: ", actualMinted);
        console2.log("Actual percentage (in thousandths): ", percent);
        
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
        
        // Calculate scale factor: (SCALE_PRECISION * 100) / percentage%
        uint256 scaleFactor = (debtToken.SCALE_PRECISION() * 100) / (percentage / 100);
        
        uint256 mintAmount = 100 * 1e18;
        
        // Update the scale factor
        vm.prank(owner);
        debtToken.whitelistIonToken(address(ionToken), scaleFactor);
        
        // Calculate expected percentage of the underlying value
        uint256 underlyingAmount = (mintAmount * EXCHANGE_RATE) / 1e18;
        uint256 underlyingValueInUsd = (underlyingAmount * TOKEN_PRICE) / TOKEN_PRICE;
        uint256 expectedMinted = underlyingValueInUsd / scaleFactor;
        
        vm.prank(user);
        debtToken.mint(address(ionToken), mintAmount);
        
        uint256 actualMinted = debtToken.balanceOf(user);
        
        console2.log("Scale factor: ", scaleFactor);
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
}

// A mock token that always fails on transferFrom
contract MockFailingIonToken is MockIonToken {
    constructor(string memory name, string memory symbol, address underlying, uint256 exchangeRate) 
        MockIonToken(name, symbol, underlying, exchangeRate) {}
    
    function transferFrom(address, address, uint256) public pure override returns (bool) {
        return false;
    }
}
