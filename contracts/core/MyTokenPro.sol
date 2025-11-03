// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "@openzeppelin/contracts/interfaces/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/draft-ERC20Permit.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Snapshot.sol";
import "@openzeppelin/contracts/access/Ownable2Step.sol";
import "@openzeppelin/contracts/utils/Nonces.sol";

import "../modules/fees/FeeProcessor.sol";
import "../modules/fees/FeeExclusions.sol";
import "../modules/staking/StakeManager.sol";
import "../modules/staking/RewardManager.sol";
import "../modules/governance/TimelockManager.sol";
import "../modules/governance/SnapshotManager.sol";
import "../modules/security/EmergencyModule.sol";
import "../modules/security/PauseModule.sol";
import "../modules/security/SecurityLimits.sol";

/**
 * @title MyTokenPro - Core contract that composes modules
 */
abstract contract MyTokenPro is
    ERC20,
    ERC20Permit,
    ERC20Burnable,
    ERC20Pausable,
    ERC20Votes,
    ERC20Snapshot,
    Ownable2Step
{
    // Módulos
    FeeProcessor public immutable feeProcessor;
    FeeExclusions public immutable feeExclusions;
    StakeManager public immutable stakeManager;
    RewardManager public immutable rewardManager;
    TimelockManager public immutable timelockManager;
    SnapshotManager public immutable snapshotManager;
    EmergencyModule public immutable emergencyModule;
    PauseModule public immutable pauseModule;
    SecurityLimits public immutable securityLimits;

    // Constantes principales
    uint256 private immutable MAX_SUPPLY = 1_000_000_000 * 1e18;
    uint256 public constant MAX_MINT_PER_CALL = 10_000_000 * 1e18;

    // Core state
    uint256 private _minted;

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
        ERC20Permit("MyTokenPro")
        Ownable2Step(initialOwner)
    {
        // Inicializar módulos en orden con parámetros correctos
        // Crear módulos - la mayoría estarán gobernados por `initialOwner`
        feeExclusions = new FeeExclusions(initialOwner);
        // FeeProcessor necesita treasury, exclusions contract y rangos iniciales
        feeProcessor = new FeeProcessor(
            address(this),
            address(feeExclusions),
            25,
            5,
            50
        );

        // Staking & rewards
        stakeManager = new StakeManager(address(this));
        rewardManager = new RewardManager(address(this), address(stakeManager));

        // Gobernanza y seguridad
        timelockManager = new TimelockManager(initialOwner);
        snapshotManager = new SnapshotManager(address(this));
        emergencyModule = new EmergencyModule(initialOwner);
        pauseModule = new PauseModule(initialOwner, address(this));
        securityLimits = new SecurityLimits(address(this));
    }

    // --------------------------------------------------
    // Hooks y delegación a módulos
    // --------------------------------------------------

    function _update(
        address from,
        address to,
        uint256 amount
    ) internal virtual override(ERC20, ERC20Pausable, ERC20Votes) {
        // Check pause and security limits first
        require(!pauseModule.isPaused(), "Token: paused");
        require(
            securityLimits.checkTransferLimit(from, amount),
            "Token: limits exceeded"
        );

        if (from != address(0) && to != address(0)) {
            // Calculate and apply fee for regular transfers
            uint256 amountAfterFee = feeProcessor.processFee(from, to, amount);
            if (amountAfterFee < amount) {
                amount = amountAfterFee;
            }
        }

        // Let parent contracts handle standard updates
        super._update(from, to, amount);
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
