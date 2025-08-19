import { describe, it, expect, beforeEach } from "vitest";

interface Bounty {
  creator: string;
  description: string;
  scopes: string[];
  rewardTiers: { low: bigint; medium: bigint; high: bigint; critical: bigint };
  escrowed: bigint;
  active: boolean;
  createdAt: bigint;
  closedAt: bigint | null;
}

interface MockContract {
  admin: string;
  paused: boolean;
  bountyCounter: bigint;
  totalEscrowed: bigint;
  bounties: Map<bigint, Bounty>;
  bountyFunds: Map<bigint, bigint>;

  isAdmin(caller: string): boolean;
  setPaused(caller: string, pause: boolean): { value: boolean } | { error: number };
  createBounty(
    caller: string,
    description: string,
    scopes: string[],
    rewardLow: bigint,
    rewardMedium: bigint,
    rewardHigh: bigint,
    rewardCritical: bigint,
    initialFund: bigint
  ): { value: bigint } | { error: number };
  fundBounty(caller: string, bountyId: bigint, amount: bigint): { value: boolean } | { error: number };
  updateRewardTiers(
    caller: string,
    bountyId: bigint,
    rewardLow: bigint,
    rewardMedium: bigint,
    rewardHigh: bigint,
    rewardCritical: bigint
  ): { value: boolean } | { error: number };
  closeBounty(caller: string, bountyId: bigint): { value: boolean } | { error: number };
}

const mockContract: MockContract = {
  admin: "ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM",
  paused: false,
  bountyCounter: 0n,
  totalEscrowed: 0n,
  bounties: new Map<bigint, Bounty>(),
  bountyFunds: new Map<bigint, bigint>(),

  isAdmin(caller: string) {
    return caller === this.admin;
  },

  setPaused(caller: string, pause: boolean) {
    if (!this.isAdmin(caller)) return { error: 100 };
    this.paused = pause;
    return { value: pause };
  },

  createBounty(
    caller: string,
    description: string,
    scopes: string[],
    rewardLow: bigint,
    rewardMedium: bigint,
    rewardHigh: bigint,
    rewardCritical: bigint,
    initialFund: bigint
  ) {
    if (this.paused) return { error: 104 };
    if (scopes.length === 0) return { error: 109 };
    if (initialFund === 0n) return { error: 105 };
    const bountyId = this.bountyCounter + 1n;
    if (this.bounties.has(bountyId)) return { error: 108 };
    this.bounties.set(bountyId, {
      creator: caller,
      description,
      scopes,
      rewardTiers: { low: rewardLow, medium: rewardMedium, high: rewardHigh, critical: rewardCritical },
      escrowed: initialFund,
      active: true,
      createdAt: 100n, // Mock block-height
      closedAt: null,
    });
    this.bountyFunds.set(bountyId, initialFund);
    this.bountyCounter = bountyId;
    this.totalEscrowed += initialFund;
    return { value: bountyId };
  },

  fundBounty(caller: string, bountyId: bigint, amount: bigint) {
    if (this.paused) return { error: 104 };
    if (amount === 0n) return { error: 105 };
    const bounty = this.bounties.get(bountyId);
    if (!bounty) return { error: 102 };
    if (!bounty.active) return { error: 103 };
    bounty.escrowed += amount;
    this.bounties.set(bountyId, bounty);
    this.bountyFunds.set(bountyId, (this.bountyFunds.get(bountyId) || 0n) + amount);
    this.totalEscrowed += amount;
    return { value: true };
  },

  updateRewardTiers(
    caller: string,
    bountyId: bigint,
    rewardLow: bigint,
    rewardMedium: bigint,
    rewardHigh: bigint,
    rewardCritical: bigint
  ) {
    if (this.paused) return { error: 104 };
    const bounty = this.bounties.get(bountyId);
    if (!bounty) return { error: 102 };
    if (bounty.creator !== caller) return { error: 100 };
    if (!bounty.active) return { error: 103 };
    bounty.rewardTiers = { low: rewardLow, medium: rewardMedium, high: rewardHigh, critical: rewardCritical };
    this.bounties.set(bountyId, bounty);
    return { value: true };
  },

  closeBounty(caller: string, bountyId: bigint) {
    if (this.paused) return { error: 104 };
    const bounty = this.bounties.get(bountyId);
    if (!bounty) return { error: 102 };
    if (bounty.creator !== caller) return { error: 100 };
    if (!bounty.active) return { error: 103 };
    const remaining = this.bountyFunds.get(bountyId) || 0n;
    bounty.active = false;
    bounty.closedAt = 200n; // Mock
    this.bounties.set(bountyId, bounty);
    this.bountyFunds.delete(bountyId);
    this.totalEscrowed -= remaining;
    return { value: true };
  },
};

describe("CyberBounty BountyFactory", () => {
  beforeEach(() => {
    mockContract.admin = "ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM";
    mockContract.paused = false;
    mockContract.bountyCounter = 0n;
    mockContract.totalEscrowed = 0n;
    mockContract.bounties = new Map();
    mockContract.bountyFunds = new Map();
  });

  it("should create a new bounty with initial fund", () => {
    const result = mockContract.createBounty(
      "ST2CY5...",
      "Find bugs in our app",
      ["web-apps", "smart-contracts"],
      100n,
      500n,
      1000n,
      5000n,
      10000n
    );
    expect(result).toEqual({ value: 1n });
    expect(mockContract.bounties.size).toBe(1);
    expect(mockContract.totalEscrowed).toBe(10000n);
  });

  it("should prevent creation when paused", () => {
    mockContract.setPaused("ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM", true);
    const result = mockContract.createBounty(
      "ST2CY5...",
      "Find bugs",
      ["web-apps"],
      100n,
      500n,
      1000n,
      5000n,
      10000n
    );
    expect(result).toEqual({ error: 104 });
  });

  it("should fund an existing bounty", () => {
    mockContract.createBounty(
      "ST2CY5...",
      "Find bugs",
      ["web-apps"],
      100n,
      500n,
      1000n,
      5000n,
      10000n
    );
    const result = mockContract.fundBounty("ST2CY5...", 1n, 5000n);
    expect(result).toEqual({ value: true });
    expect(mockContract.totalEscrowed).toBe(15000n);
  });

  it("should update reward tiers by creator", () => {
    mockContract.createBounty(
      "ST2CY5...",
      "Find bugs",
      ["web-apps"],
      100n,
      500n,
      1000n,
      5000n,
      10000n
    );
    const result = mockContract.updateRewardTiers("ST2CY5...", 1n, 200n, 600n, 1200n, 6000n);
    expect(result).toEqual({ value: true });
    const bounty = mockContract.bounties.get(1n);
    expect(bounty?.rewardTiers.low).toBe(200n);
  });

  it("should close a bounty and reset escrow", () => {
    mockContract.createBounty(
      "ST2CY5...",
      "Find bugs",
      ["web-apps"],
      100n,
      500n,
      1000n,
      5000n,
      10000n
    );
    const result = mockContract.closeBounty("ST2CY5...", 1n);
    expect(result).toEqual({ value: true });
    const bounty = mockContract.bounties.get(1n);
    expect(bounty?.active).toBe(false);
    expect(mockContract.totalEscrowed).toBe(0n);
  });

  it("should prevent non-creator from closing bounty", () => {
    mockContract.createBounty(
      "ST2CY5...",
      "Find bugs",
      ["web-apps"],
      100n,
      500n,
      1000n,
      5000n,
      10000n
    );
    const result = mockContract.closeBounty("ST3NB...", 1n);
    expect(result).toEqual({ error: 100 });
  });
});