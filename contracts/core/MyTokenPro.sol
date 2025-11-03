// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "./extensions/TokenBurn.sol";
import "./extensions/TokenPause.sol"; // Added for ERC20Pausable
import "./extensions/TokenPermit.sol"; // Added for ERC20Permit
import "./extensions/TokenSnapshot.sol"; // Added for ERC20Snapshot
import "./extensions/TokenVotes.sol"; // Added for ERC20Votes
import "./token/TokenSupply.sol"; // Added for MAX_MINT_PER_CALL, MAX_SUPPLY, _minted

import "./integration/SecurityIntegration.sol";
import "./integration/StakingIntegration.sol";
import "./integration/FeeIntegration.sol";
import "./integration/GovernanceIntegration.sol";
import "./transfer/TransferProcessor.sol";
import "./transfer/TransferValidation.sol";
import "./events/CoreEvents.sol";
import "./events/SecurityEvents.sol";

// Import module contracts
import "../modules/fees/FeeExclusions.sol";
import "../modules/fees/FeeProcessor.sol";
import "../modules/staking/StakeManager.sol";
import "../modules/staking/RewardManager.sol";
import "../modules/governance/TimelockManager.sol";
import "../modules/governance/SnapshotManager.sol";
import "../modules/security/EmergencyModule.sol";
import "../modules/security/PauseModule.sol";
import "../modules/security/SecurityLimits.sol";

/**
 * @title MyTokenPro - Core contract that integrates all modules
 * @notice Main entry point for the token system that coordinates all modular functionality
 */
contract MyTokenPro is
    TokenBurn,
    TokenPause, // Explicitly inherit TokenPause
    TokenPermit, // Explicitly inherit TokenPermit
    TokenSnapshot, // Explicitly inherit TokenSnapshot
    TokenVotes, // Explicitly inherit TokenVotes
    TokenSupply // Explicitly inherit TokenSupply
{
    // Module integrations
    SecurityIntegration public immutable securityIntegration;
    StakingIntegration public immutable stakingIntegration;
    FeeIntegration public immutable feeIntegration;
    GovernanceIntegration public immutable governanceIntegration;

    // Module instances (declared as state variables)
    FeeExclusions public immutable feeExclusions;
    FeeProcessor public immutable feeProcessor;
    StakeManager public immutable stakeManager;
    RewardManager public immutable rewardManager;
    TimelockManager public immutable timelockManager;
    SnapshotManager public immutable snapshotManager;
    EmergencyModule public immutable emergencyModule;
    PauseModule public immutable pauseModule;
    SecurityLimits public immutable securityLimits;
    TransferProcessor public immutable transferProcessor; // Added
    TransferValidation public immutable transferValidation; // Added

    // Events that are core-specific
    event Mint(address indexed to, uint256 amount, uint256 totalMinted);
    event EmergencyWithdrawal(
        address indexed token,
        address indexed to,
        uint256 amount
    );
    event SecurityLimitHit(
        string limitType,
        address indexed user,
        uint256 amount
    );
    event AntiFlashLoanTriggered(address indexed user, uint256 blocksStaked);

    constructor(
        address initialOwner
    )
        ERC20("MyTokenPro", "MTP")
        Ownable2Step(initialOwner)
    {
        // Crear módulos - la mayoría estarán gobernados por `initialOwner`
        feeExclusions = new FeeExclusions(initialOwner);
        feeProcessor = new FeeProcessor(
            address(this),
            address(feeExclusions),
            25,
            5,
            50
        );

        stakeManager = new StakeManager(address(this));
        rewardManager = new RewardManager(address(this), address(stakeManager));

        timelockManager = new TimelockManager(initialOwner);
        snapshotManager = new SnapshotManager(address(this));
        emergencyModule = new EmergencyModule(initialOwner);
        pauseModule = new PauseModule(initialOwner, address(this));
        securityLimits = new SecurityLimits(address(this));

        // Initialize transfer modules
        transferProcessor = new TransferProcessor(
            address(feeIntegration), // Pass feeIntegration for fee processing
            address(securityIntegration) // Pass securityIntegration for security checks
        );
        transferValidation = new TransferValidation(
            address(securityIntegration), // Pass securityIntegration for security checks
            address(pauseModule) // Pass pauseModule for pause checks
        );

        // Inicializar módulos de integración
        securityIntegration = new SecurityIntegration(
            address(emergencyModule),
            address(pauseModule),
            address(securityLimits)
        );
        // Authorize TransferProcessor to call validateTransfer on SecurityIntegration
        // This is necessary because TransferProcessor now delegates security checks to SecurityIntegration.
        securityIntegration.authorizeModule(address(transferProcessor), securityIntegration.SECURITY_LIMIT_ROLE());
        stakingIntegration = new StakingIntegration(
            address(stakeManager),
            address(rewardManager)
        );
        feeIntegration = new FeeIntegration(
            address(feeProcessor),
            address(feeExclusions)
        );
        governanceIntegration = new GovernanceIntegration(
            address(timelockManager),
            address(snapshotManager)
        );
    }

    // --------------------------------------------------
    // Hooks y delegación a módulos
    // --------------------------------------------------

    function _update(
        address from,
        address to,
        uint256 amount
    ) internal virtual override(ERC20, ERC20Pausable, ERC20Votes, ERC20Snapshot) {
        // Delegate validation to TransferValidation module
        transferValidation.validateTransfer(from, to, amount);

        // Delegate processing to TransferProcessor module
        uint256 amountAfterProcessing = transferProcessor.processTransfer(from, to, amount);

        // Let parent contracts handle standard updates with the processed amount
        super._update(from, to, amountAfterProcessing);
    }

    // Snapshot/pause hooks handled via ERC20's newer _update mechanism and
    // by the modules; explicit _beforeTokenTransfer override removed to
    // match the OpenZeppelin versions used in this project.

    // --------------------------------------------------
    // Implementación de interfaces de módulos
    // --------------------------------------------------

    function mint(address to, uint256 amount) external {
        require(
            msg.sender == address(rewardManager),
            "Token: only reward manager"
        );
        require(amount <= MAX_MINT_PER_CALL, "Token: max mint exceeded");
        require(_minted + amount <= MAX_SUPPLY, "Token: max supply exceeded");
        _minted += amount;
        _mint(to, amount);
        emit Mint(to, amount, _minted);
    }

    function pause() external {
        require(
            msg.sender == address(emergencyModule),
            "Token: only emergency module"
        );
        pauseModule.pause();
    }

    function unpause() external {
        require(
            msg.sender == address(emergencyModule),
            "Token: only emergency module"
        );
        pauseModule.unpause();
    }

    function createSnapshot() external returns (uint256) {
        require(
            msg.sender == address(snapshotManager),
            "Token: only snapshot manager"
        );
        return snapshotManager.createSnapshot();
    }

    // legacy proxy removed

    // --------------------------------------------------
    // Funciones públicas
    // --------------------------------------------------

    function burn(uint256 amount) public virtual override {
        super.burn(amount);
    }

    function snapshot() external returns (uint256) {
        return snapshotManager.createSnapshot();
    }

    function stake(uint256 amount) external {
        stakeManager.stake(amount);
    }

    function unstake(uint256 amount) external {
        stakeManager.unstake(amount);
    }

    function claimReward() external {
        rewardManager.claimReward();
    }

    function transfer(
        address to,
        uint256 amount
    ) public virtual override returns (bool) {
        address owner = _msgSender();
        _transfer(owner, to, amount);
        return true;
    }

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) public virtual override returns (bool) {
        address spender = _msgSender();
        _spendAllowance(from, spender, amount);
        _transfer(from, to, amount);
        return true;
    }

    // Note: overrides for ERC20Votes/ERCSnapshot hooks removed to match imported OZ versions.

    // Implement nonces forwarding
    function nonces(
        address owner
    ) public view override(ERC20Permit, Nonces) returns (uint256) {
        return super.nonces(owner);
    }

    // Expose some getters
    function stakingPool() external view returns (uint256) {
        return stakeManager.stakingPool();
    }

    function totalStaked() external view returns (uint256) {
        return stakeManager.totalStaked();
    }

    function stakedBalance(address user) external view returns (uint256) {
        return stakeManager.stakedBalance(user);
    }

    function treasury() external view returns (address) {
        return feeProcessor.treasury();
    }

    function excludedCount() external view returns (uint256) {
        return feeProcessor.excludedCount();
    }
}
