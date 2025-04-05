// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.20;

interface IERC20 {
  function balanceOf(address account) external view returns (uint256);
  function transfer(address to, uint256 value) external returns (bool);
}

contract ERC20MultisigWithdrawals {
  IERC20 token;
  address[] owners;
  uint threshhold;
  bytes cardanoPolicy;
  uint tick; // increment every withdrawal

  constructor(IERC20 _token, address[] memory _owners, uint _threshhold) {
    token = _token;
    owners = _owners;
    cardanoPolicy = ""; // start empty and register later (because the cardanoPolicy depends on the ethereum contract address)
    threshhold = _threshhold;
	tick = 0;
  }

  function registerCardanoPolicy(
    bytes memory _policy
  ) public returns (bool) {
    require(cardanoPolicy.length == 0, "Cardano policy already set");
    require(_policy.length == 28, "New policy not 28 bytes long");
    cardanoPolicy = _policy;
    return true;
  }

  function withdraw(
    address recipient,
    uint256 amount,
    uint256 V, // value of all wrapped tokens on Cardano side
    uint t, // time at which V was recorded, seconds since 1970
    bytes[] memory signatures
  ) public returns (bool) {
    require(cardanoPolicy.length == 28, "Cardano policy not yet set");
	  require(t > block.timestamp - 300, "V timestamp too old");
	  require(t < block.timestamp + 300, "V timestamp too new");
	
	  uint256 R = token.balanceOf(address(this));
	  require(V - amount >= R, "can't withdraw more than wrapped value");

    bytes32 messageHash = keccak256(
      abi.encodePacked(
        cardanoPolicy,
        V,
        t,
        tick,
        recipient,
        amount
      )
    );
    bytes32 safeMessageHash = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", messageHash));

    uint n = signatures.length;
    address[] memory signers = new address[](n);
    for (uint i = 0; i < signatures.length; i++) {
      signers[i] = recoverSigner(signatures[i], safeMessageHash);
    }

    uint count = 0;
    for (uint i = 0; i < owners.length; i++) {
      address owner = owners[i];
	  for (uint j = 0; j < n; j++) {
        if (signers[j] == owner) {
          count += 1;
		  break;
		}
	  }
    }

    require(count >= threshhold, "not enough owner signatures");

    tick += 1;

    return token.transfer(recipient, amount);
  }

  function recoverSigner(bytes memory signature, bytes32 hash) internal pure returns (address) {
    (bytes32 r, bytes32 s, uint8 v) = splitSignature(signature);
		
    return ecrecover(hash, v, r, s);
  }

  function splitSignature(bytes memory signature) internal pure returns (bytes32 r, bytes32 s, uint8 v) {
    require(signature.length == 65, "Invalid signature length");

    assembly {
      r := mload(add(signature, 32))
      s := mload(add(signature, 64))
      v := byte(0, mload(add(signature, 96)))
    }
  }
}