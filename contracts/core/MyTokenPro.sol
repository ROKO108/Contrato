// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

// ================================================================
// Core Token Components
// ================================================================
import "./token/TokenSupply.sol";
import "./extensions/TokenBurn.sol";
import "./extensions/TokenPause.sol";
import "./extensions/TokenPermit.sol";
import "./extensions/TokenSnapshot.sol";
import "./extensions/TokenVotes.sol";

// ================================================================
// Transfer Management
// ================================================================
import "./transfer/TransferProcessor.sol";
import "./transfer/TransferValidation.sol";

// ================================================================
// Integration Contracts
// ================================================================
import "./integration/SecurityIntegration.sol";
import "./integration/StakingIntegration.sol";
import "./integration/FeeIntegration.sol";
import "./integration/GovernanceIntegration.sol";

// ================================================================
// Event Definitions
// ================================================================
import "./events/CoreEvents.sol";
import "./events/SecurityEvents.sol";

// ================================================================
// Module Contracts
// ================================================================
// Fee Modules
import "../modules/fees/FeeExclusions.sol";
import "../modules/fees/FeeProcessor.sol";

// Staking Modules
import "../modules/staking/StakeManager.sol";
import "../modules/staking/RewardManager.sol";

// Governance Modules
import "../modules/governance/TimelockManager.sol";
import "../modules/governance/SnapshotManager.sol";

// Security Modules
import "../modules/security/EmergencyModule.sol";
import "../modules/security/PauseModule.sol";
import "../../modules/security/SecurityLimits.sol";

/**
 * @title MyTokenPro - Core contract that integrates all modules
 * @notice Main entry point for the token system that coordinates all modular functionality
 */
contract MyTokenPro is
    TokenBurn,
    TokenPause,
    TokenPermit,
    TokenSnapshot,
    TokenVotes,
    TokenSupply
{
    // Module integrations
    SecurityIntegration public immutable securityIntegration;
    StakingIntegration public immutable stakingIntegration;
    FeeIntegration public immutable feeIntegration;
    GovernanceIntegration public immutable governanceIntegration;

    // Module instances
    FeeExclusions public immutable feeExclusions;
    FeeProcessor public immutable feeProcessor;
    StakeManager public immutable stakeManager;
    RewardManager public immutable rewardManager;
    TimelockManager public immutable timelockManager;
    SnapshotManager public immutable snapshotManager;
    EmergencyModule public immutable emergencyModule;
    PauseModule public immutable pauseModule;
    SecurityLimits public immutable securityLimits;
    TransferProcessor public immutable transferProcessor;
    TransferValidation public immutable transferValidation;

    // Events
    event Mint(address indexed to, uint256 amount, uint256 totalMinted);
    event EmergencyWithdrawal(address indexed token, address indexed to, uint256 amount);
    event SecurityLimitHit(string limitType, address indexed user, uint256 amount);
    event AntiFlashLoanTriggered(address indexed user, uint256 blocksStaked);

    modifier onlyModule(address _module) {
        require(msg.sender == _module, "Token: unauthorized module");
        _;
    }

constructor(address initialOwner)
        ERC20("MyTokenPro", "MTP"), Ownable2Step(initialOwner)
    {
        require(initialOwner != address(0), "Token: zero owner");
        _initBaseModules(initialOwner);
        _initIntegrations();
        _initTransferModules();
        _authorizeModules();
    }

    // ================================================================
    // Internal initialization helpers
    // ================================================================

function _initBaseModules(address initialOwner) private {
        feeExclusions   = new FeeExclusions(initialOwner);
        feeProcessor    = new FeeProcessor(address(this), address(feeExclusions), 25, 5, 50, initialOwner);

        stakeManager    = new StakeManager(address(this));
        rewardManager   = new RewardManager(address(this), address(stakeManager));

        timelockManager = new TimelockManager(initialOwner);
        snapshotManager = new SnapshotManager(address(this));
        emergencyModule = new EmergencyModule(initialOwner);
        pauseModule     = new PauseModule(initialOwner, address(this));
        securityLimits  = new SecurityLimits(address(this));
    }

    function _initIntegrations() private {
        securityIntegration = new SecurityIntegration(
            address(emergencyModule),
            address(pauseModule),
            address(securityLimits)
        );

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

    function _initTransferModules() private {
        transferProcessor = new TransferProcessor(
            address(feeIntegration),
            address(securityIntegration)
        );

        transferValidation = new TransferValidation(
            address(securityIntegration),
            address(pauseModule)
        );
    }

function _authorizeModules() private {
        // Standardized module authorization pattern
        _authorizeSecurityModules();
        _authorizeFeeModules();
        _authorizeStakingModules();
        _authorizeGovernanceModules();
    }
    
    function _authorizeSecurityModules() private {
        securityIntegration.authorizeModule(
            address(transferProcessor),
            securityIntegration.SECURITY_LIMIT_ROLE()
        );
        securityIntegration.authorizeModule(
            address(transferValidation),
            securityIntegration.SECURITY_LIMIT_ROLE()
        );
    }
    
    function _authorizeFeeModules() private {
        feeIntegration.authorizeModule(
            address(transferProcessor),
            feeIntegration.FEE_PROCESSOR_ROLE()
        );
    }
    
    function _authorizeStakingModules() private {
        stakingIntegration.authorizeModule(
            address(rewardManager),
            stakingIntegration.REWARD_MANAGER_ROLE()
        );
    }
    
    function _authorizeGovernanceModules() private {
        governanceIntegration.authorizeModule(
            address(snapshotManager),
            governanceIntegration.SNAPSHOT_MANAGER_ROLE()
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
        transferValidation.validateTransfer(from, to, amount);
        uint256 amountAfterProcessing = transferProcessor.processTransfer(from, to, amount);
        super._update(from, to, amountAfterProcessing);
    }

    // --------------------------------------------------
    // Implementación de interfaces de módulos
    // --------------------------------------------------
    function mint(address to, uint256 amount) external onlyModule(address(rewardManager)) {
        require(to != address(0), "Token: zero address");
        require(amount > 0, "Token: zero amount");
        require(amount <= MAX_MINT_PER_CALL, "Token: max mint exceeded");
        require(_minted + amount <= MAX_SUPPLY, "Token: max supply exceeded");
        
        // Prevent overflow
        unchecked { 
            _minted += amount; 
            require(_minted <= MAX_SUPPLY, "Token: overflow");
        }
        
        _mint(to, amount);
        emit Mint(to, amount, _minted);
    }

    function pause() external {
        require(msg.sender == address(emergencyModule), "Token: only emergency module");
        pauseModule.pause();
    }

    function unpause() external {
        require(msg.sender == address(emergencyModule), "Token: only emergency module");
        pauseModule.unpause();
    }

    function createSnapshot() external returns (uint256) {
        require(msg.sender == address(snapshotManager), "Token: only snapshot manager");
        return snapshotManager.createSnapshot();
    }

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

    function transfer(address to, uint256 amount)
        public
        virtual
        override
        returns (bool)
    {
        address owner = _msgSender();
        _transfer(owner, to, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount)
        public
        virtual
        override
        returns (bool)
    {
        address spender = _msgSender();
        _spendAllowance(from, spender, amount);
        _transfer(from, to, amount);
        return true;
    }

    function nonces(address owner)
        public
        view
        override(ERC20Permit, Nonces)
        returns (uint256)
    {
        return super.nonces(owner);
    }

    // --------------------------------------------------
    // Getters auxiliares
    // --------------------------------------------------
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
