import {
    Clarinet,
    Tx,
    Chain,
    Account,
    types
} from 'https://deno.land/x/clarinet@v1.0.0/index.ts';
import { assertEquals } from 'https://deno.land/std@0.90.0/testing/asserts.ts';

Clarinet.test({
    name: "Ensure only owner can register nodes",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const deployer = accounts.get('deployer')!;
        const wallet1 = accounts.get('wallet_1')!;
        
        let block = chain.mineBlock([
            // Owner registration should succeed
            Tx.contractCall('loop-guard', 'register-node', [
                types.principal(wallet1.address)
            ], deployer.address),
            
            // Non-owner registration should fail
            Tx.contractCall('loop-guard', 'register-node', [
                types.principal(wallet1.address)
            ], wallet1.address)
        ]);
        
        block.receipts[0].result.expectOk();
        block.receipts[1].result.expectErr(types.uint(100)); // err-owner-only
    }
});

Clarinet.test({
    name: "Test node registration and status updates",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const deployer = accounts.get('deployer')!;
        const wallet1 = accounts.get('wallet_1')!;
        
        let block = chain.mineBlock([
            Tx.contractCall('loop-guard', 'register-node', [
                types.principal(wallet1.address)
            ], deployer.address)
        ]);
        
        block.receipts[0].result.expectOk();
        
        // Update node status
        let statusBlock = chain.mineBlock([
            Tx.contractCall('loop-guard', 'update-node-status', [
                types.principal(wallet1.address),
                types.ascii("running")
            ], wallet1.address)
        ]);
        
        statusBlock.receipts[0].result.expectOk();
        
        // Check node info
        let infoBlock = chain.mineBlock([
            Tx.contractCall('loop-guard', 'get-node-info', [
                types.principal(wallet1.address)
            ], deployer.address)
        ]);
        
        const nodeInfo = infoBlock.receipts[0].result.expectOk().expectSome();
        assertEquals(nodeInfo['status'], "running");
        assertEquals(nodeInfo['active'], true);
    }
});

Clarinet.test({
    name: "Test node group creation and management",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const deployer = accounts.get('deployer')!;
        const wallet1 = accounts.get('wallet_1')!;
        
        // Create node group
        let groupBlock = chain.mineBlock([
            Tx.contractCall('loop-guard', 'create-node-group', [
                types.ascii("test-group"),
                types.ascii("Test group description"),
                types.bool(true),
                types.uint(100)
            ], deployer.address)
        ]);
        
        groupBlock.receipts[0].result.expectOk();
        const groupId = groupBlock.receipts[0].result.expectOk();
        
        // Register node
        let registerBlock = chain.mineBlock([
            Tx.contractCall('loop-guard', 'register-node', [
                types.principal(wallet1.address)
            ], deployer.address)
        ]);
        
        registerBlock.receipts[0].result.expectOk();
        
        // Add node to group
        let addToGroupBlock = chain.mineBlock([
            Tx.contractCall('loop-guard', 'add-node-to-group', [
                types.principal(wallet1.address),
                types.uint(0)
            ], deployer.address)
        ]);
        
        addToGroupBlock.receipts[0].result.expectOk();
        
        // Check group info
        let groupInfoBlock = chain.mineBlock([
            Tx.contractCall('loop-guard', 'get-group-info', [
                types.uint(0)
            ], deployer.address)
        ]);
        
        const groupInfo = groupInfoBlock.receipts[0].result.expectOk().expectSome();
        assertEquals(groupInfo['name'], "test-group");
        assertEquals(groupInfo['members'].length, 1);
    }
});

Clarinet.test({
    name: "Test node revocation",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const deployer = accounts.get('deployer')!;
        const wallet1 = accounts.get('wallet_1')!;
        
        // Register and revoke node
        let block = chain.mineBlock([
            Tx.contractCall('loop-guard', 'register-node', [
                types.principal(wallet1.address)
            ], deployer.address),
            
            Tx.contractCall('loop-guard', 'revoke-node', [
                types.principal(wallet1.address)
            ], deployer.address)
        ]);
        
        block.receipts[0].result.expectOk();
        block.receipts[1].result.expectOk();
        
        // Try to update revoked node
        let updateBlock = chain.mineBlock([
            Tx.contractCall('loop-guard', 'update-node-status', [
                types.principal(wallet1.address),
                types.ascii("running")
            ], wallet1.address)
        ]);
        
        updateBlock.receipts[0].result.expectErr(types.uint(103)); // err-revoked
    }
});
