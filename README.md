# LoopGuard

A secure blockchain-based tool for managing IoT nodes built on Stacks. LoopGuard enables secure registration, authentication and management of IoT devices using smart contracts.

## Features
- Register new IoT nodes with unique identifiers
- Authenticate nodes before allowing operations 
- Manage node permissions and access control
- Track node activity and status
- Revoke compromised nodes
- Group-based node management
  - Create and manage node groups
  - Assign nodes to groups
  - Group-level settings and policies
  - Automatic node revocation based on group policies
  - Track group membership and activity

## Security
The contract implements various security measures including:
- Node authentication checks
- Permission-based access control
- Activity logging
- Node status tracking
- Emergency node revocation
- Group-based policy enforcement
- Inactivity monitoring and auto-revocation

## Node Groups
The group management system allows:
- Creating named groups with descriptions
- Configuring group-wide settings
- Setting inactivity thresholds
- Enabling automatic revocation
- Managing group membership
- Monitoring group activity
