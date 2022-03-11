// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import {WithRaceStorage} from "./libraries/LibStorage.sol";

contract RaceInit is WithRaceStorage {
    function init(
        uint256 roundEnd,
        uint256 claimPlanetCooldown
    ) external {
        rs().roundEnd = roundEnd;
        rs().CLAIM_PLANET_COOLDOWN = claimPlanetCooldown;
    }
}
