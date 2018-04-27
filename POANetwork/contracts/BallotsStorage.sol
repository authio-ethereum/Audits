pragma solidity ^0.4.18;
import "./interfaces/IBallotsStorage.sol";
import "./interfaces/IProxyStorage.sol";
import "./interfaces/IPoaNetworkConsensus.sol";
import "./SafeMath.sol";


//@audit - This contract serves as storage for the number of votes required to pass certain ballots
contract BallotsStorage is IBallotsStorage {
    using SafeMath for uint256;

    //@audit - Enum representing a type of threshold - which aspect is being voted on or changed
    enum ThresholdTypes {Invalid, Keys, MetadataChange}
    //@audit - Address of ProxyStorage contract, cast to an inerface
    IProxyStorage public proxyStorage;
    //@audit - Maps a type of ballot to a threshold of votes required to pass that ballot
    mapping(uint8 => uint256) ballotThresholds;

    //@audit - Modifier: Sender must be voting to change threshold contract
    modifier onlyVotingToChangeThreshold() {
        require(msg.sender == getVotingToChangeThreshold());
        _;
    }

    //@audit - Constructor: Sets the proxyStorage contract address
    function BallotsStorage(address _proxyStorage) public {
        //@audit - Set the proxyStorage contract address, cast to an interface
        proxyStorage = IProxyStorage(_proxyStorage);
        //@audit - Set the ballot threshold for Keys to 3
        ballotThresholds[uint8(ThresholdTypes.Keys)] = 3;
        //@audit - Set the ballot threshold for validator metadata change to 2
        ballotThresholds[uint8(ThresholdTypes.MetadataChange)] = 2;
    }

    //@audit - Set the voting threshold to a new value
    //@audit - MODIFIER: Sender must be voting to change threshold contract
    function setThreshold(uint256 _newValue, uint8 _thresholdType) public onlyVotingToChangeThreshold {
        //@audit - Ensure the thresholdType is nonzero
        require(_thresholdType > 0);
        //@audit - Ensure the thresholdType will not overflow to an invalid type
        require(_thresholdType <= uint8(ThresholdTypes.MetadataChange));
        //@audit - Ensure the new value is nonzero, and that it is not equal to the current value
        require(_newValue > 0 && _newValue != ballotThresholds[_thresholdType]);
        //@audit - Set the new value as the voting threshold for the given type
        ballotThresholds[_thresholdType] = _newValue;
    }

    //@audit - Return the voting threshold for a given ballot type
    function getBallotThreshold(uint8 _ballotType) public view returns(uint256) {
        return ballotThresholds[_ballotType];
    }

    //@audit - Return the voting to change minimum threshold from the ProxyStorage contract
    function getVotingToChangeThreshold() public view returns(address) {
        return proxyStorage.getVotingToChangeMinThreshold();
    }

    //@audit - Get the current total number of validators
    function getTotalNumberOfValidators() public view returns(uint256) {
        //@audit - Get the poaConsensus contact address from the ProxyStorage contract
        IPoaNetworkConsensus poa = IPoaNetworkConsensus(proxyStorage.getPoaConsensus());
        //@audit - Return the length of the validators array
        return poa.currentValidatorsLength();
    }

    //@audit - Return the threshold for 51% of voters
    function getProxyThreshold() public view returns(uint256) {
        //@audit - ()(total number of validators) / 2) + 1
        return getTotalNumberOfValidators().div(2).add(1);
    }
}
