// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

struct ClaimedCoords {
    uint256 locationId;
    uint256 x;
    uint256 y;
    address claimer;
    uint256 score;
    uint256 claimedAt;
}

struct LastClaimedStruct {
    address player;
    uint256 lastClaimTimestamp;
}
