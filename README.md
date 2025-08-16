# 📦 Shipment Tracking Contract

A decentralized shipment tracking system built on the Stacks blockchain using Clarity smart contracts.

## 🚀 Features

- 📋 **Create Shipments**: Register new shipments with sender, receiver, and carrier details
- 📍 **Real-time Tracking**: Track shipment status and location updates
- 🏢 **Carrier Management**: Authorize and manage shipping carriers
- ⏰ **Delivery Estimates**: Set and update estimated delivery times
- 📊 **Performance Analytics**: Track carrier performance metrics
- 🔒 **Secure Updates**: Role-based permissions for shipment updates
- ⚡ **Exception Handling**: Report and manage delivery exceptions

## 📝 Contract Functions

### Public Functions

#### Carrier Management
- `authorize-carrier` - Authorize a new carrier (owner only) 🔐
- `revoke-carrier` - Revoke carrier authorization (owner only) ❌

#### Shipment Operations
- `create-shipment` - Create a new shipment 📦
- `update-shipment-status` - Update shipment status and location 📍
- `pickup-shipment` - Mark shipment as picked up 🚚
- `mark-in-transit` - Mark shipment as in transit 🛣️
- `mark-out-for-delivery` - Mark shipment out for delivery 🏠
- `deliver-shipment` - Mark shipment as delivered ✅
- `report-exception` - Report delivery exceptions ⚠️
- `confirm-delivery` - Confirm delivery (receiver only) ✔️
- `update-estimated-delivery` - Update delivery estimate ⏰
- `cancel-shipment` - Cancel a shipment ❌

### Read-Only Functions

#### Shipment Information
- `get-shipment` - Get shipment details 📋
- `get-shipment-updates` - Get all updates for a shipment 📈
- `get-shipment-timeline` - Get complete shipment history ⏳
- `get-shipment-history` - Get shipment and update history 📚

#### Status Checks
- `is-shipment-delivered` - Check if shipment is delivered ✅
- `is-shipment-delayed` - Check if shipment is delayed ⚠️
- `verify-tracking-hash` - Verify shipment tracking hash 🔍

#### User Functions
- `get-shipments-by-sender` - Get shipments sent by user 📤
- `get-shipments-by-receiver` - Get shipments received by user 📥
- `get-shipments-by-carrier` - Get shipments handled by carrier 🚛

#### Analytics
- `get-carrier-performance` - Get carrier performance metrics 📊
- `get-active-shipments-count` - Count active shipments 🔢
- `get-total-shipments` - Get total shipment count 📈

## 🛠️ Setup & Usage

### Prerequisites
- [Clarinet](https://github.com/hirosystems/clarinet) installed
- Node.js for testing

### Installation
```bash
git clone <repository-url>
cd Shipment-Tracking-Contract
clarinet check
```

### Testing
```bash
npm install
npm test
```

## 📖 Usage Examples

### 1. Authorize a Carrier
```clarity
(contract-call? .shipment-tracking authorize-carrier 'SP2J6ZY48GV1EZ5V2V5RB9MP66SW86PYKKNRV9EJ7 "FedEx")
```

### 2. Create a Shipment
```clarity
(contract-call? .shipment-tracking create-shipment
  'SP2J6ZY48GV1EZ5V2V5RB9MP66SW86PYKKNRV9EJ7  ;; receiver
  'SP3FBR2AGK5H9QBDH3EEN6DF8EK8JY7RX8QJ5SVTE  ;; carrier
  "New York"                                   ;; origin
  "Los Angeles"                                ;; destination
  u1000                                        ;; estimated delivery block
  u500                                         ;; value
  u25                                          ;; weight
  "abc123def456"                               ;; tracking hash
)
```

### 3. Update Shipment Status
```clarity
(contract-call? .shipment-tracking update-shipment-status u1 "in-transit" "Chicago Hub" "Package sorted at hub")
```

### 4. Track Shipment
```clarity
(contract-call? .shipment-tracking get-shipment u1)
(contract-call? .shipment-tracking get-shipment-updates u1)
```

## 📋 Shipment Statuses

- `created` - Shipment created and awaiting pickup 📝
- `picked-up` - Package picked up by carrier 📦
- `in-transit` - Package in transit to destination 🚛
- `out-for-delivery` - Package out for final delivery 🏠
- `delivered` - Package successfully delivered ✅
- `exception` - Delivery exception occurred ⚠️
- `cancelled` - Shipment cancelled ❌
- `returned` - Package returned to sender 🔄

## 🔐 Security Features

- **Owner-only Functions**: Carrier authorization requires contract owner
- **Role-based Access**: Only authorized parties can update shipments
- **Input Validation**: All status transitions validated
- **Tracking Hash**: Secure shipment verification

## 🏗️ Contract Architecture

The contract uses several maps to efficiently store and retrieve data:
- `shipments` - Main shipment data
- `shipment-updates` - Tracking updates history
- `authorized-carriers` - Authorized carrier registry
- `user-shipments` - User role mappings


## 📄 License

This project is open source and available under the MIT License.
