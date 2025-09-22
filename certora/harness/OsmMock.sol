// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.21;

contract OsmMock {

    uint256 public curVal;
    bool    public curHas;
    uint256 public nxtVal;
    bool    public nxtHas;
    uint256 public nxtNxtVal;
    bool    public nxtNxtHas;
    uint256 public stopped;
    address public src;
    uint16  public hop;
    uint64  public zzz;
    bool    public pass;

    function peek() external view returns (bytes32,bool) {
        return (bytes32(curVal), curHas);
    }

    function peep() external view returns (bytes32,bool) {
        return (bytes32(nxtVal), nxtHas);
    }

    function read() external view returns (bytes32) {
        require(curHas);
        return (bytes32(curVal));
    }

    function poke() external {
        curVal = nxtVal;
        nxtVal = nxtNxtVal;
        zzz = uint64(block.timestamp);
    }
}
