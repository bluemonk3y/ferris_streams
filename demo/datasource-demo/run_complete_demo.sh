#!/bin/bash

# FerrisStreams DataSource Demo - Complete Pipeline Runner
# Demonstrates file -> processing -> kafka -> analytics -> file pipeline

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'  
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
DEMO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DATA_DIR="$DEMO_DIR/demo_data"
OUTPUT_DIR="$DEMO_DIR/demo_output"
CONFIG_DIR="$DEMO_DIR/configs"

echo -e "${BLUE}🚀 FerrisStreams DataSource Complete Demo${NC}"
echo -e "${BLUE}=========================================${NC}"

# Function to print status
print_status() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"  
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check prerequisites  
echo -e "${BLUE}📋 Checking Prerequisites${NC}"
echo "================================"

# Check Rust/Cargo
if ! command_exists cargo; then
    print_error "Cargo not found. Please install Rust: https://rustup.rs/"
    exit 1
fi
print_status "Rust/Cargo found"

# Check Docker (for Kafka)
if ! command_exists docker; then
    print_warning "Docker not found. Kafka features will be limited."
    SKIP_KAFKA=true
else
    print_status "Docker found"
fi

# Check if in correct directory
if [[ ! -f "$DEMO_DIR/../../Cargo.toml" ]]; then
    print_error "Please run this script from the demo/datasource-demo directory"
    exit 1
fi
print_status "Running from correct directory"

# Setup directories
echo -e "\n${BLUE}📁 Setting Up Directories${NC}"
echo "============================="

mkdir -p "$DATA_DIR" "$OUTPUT_DIR"
print_status "Created demo directories"

# Build FerrisStreams binaries
echo -e "\n${BLUE}🔨 Building FerrisStreams${NC}"
echo "=========================="

cd "$DEMO_DIR/../.."

echo "Building core binaries..."
RUSTFLAGS="-A dead_code" cargo build --bin file_processing_demo --no-default-features --quiet
RUSTFLAGS="-A dead_code" cargo build --bin ferris-sql --no-default-features --quiet  
RUSTFLAGS="-A dead_code" cargo build --bin ferris-sql-multi --no-default-features --quiet

if [[ "$SKIP_KAFKA" != "true" ]]; then
    echo "Building with Kafka support..."
    RUSTFLAGS="-A dead_code" cargo build --bin complete_pipeline_demo --quiet
fi

print_status "FerrisStreams built successfully"

# Generate demo data if needed
echo -e "\n${BLUE}📊 Preparing Demo Data${NC}"
echo "======================="

if [[ ! -f "$DATA_DIR/financial_transactions.csv" ]]; then
    echo "Generating financial transaction data..."
    cd "$DEMO_DIR"
    if [[ -x "./generate_demo_data.sh" ]]; then
        ./generate_demo_data.sh
    else
        # Fallback: create minimal demo data
        echo "transaction_id,customer_id,amount,currency,timestamp,merchant_category,description" > "$DATA_DIR/financial_transactions.csv"
        echo "TXN001,CUST001,123.45,USD,1704110400,restaurant,Demo Transaction 1" >> "$DATA_DIR/financial_transactions.csv"
        echo "TXN002,CUST002,67.89,USD,1704111000,grocery,Demo Transaction 2" >> "$DATA_DIR/financial_transactions.csv"
        echo "TXN003,CUST001,45.67,USD,1704111600,gas,Demo Transaction 3" >> "$DATA_DIR/financial_transactions.csv"
    fi
else
    echo "Using existing demo data"
fi

RECORD_COUNT=$(tail -n +2 "$DATA_DIR/financial_transactions.csv" | wc -l)
print_status "Demo data ready: $RECORD_COUNT transactions"

# Start Kafka (if available)
if [[ "$SKIP_KAFKA" != "true" ]]; then
    echo -e "\n${BLUE}🔄 Starting Kafka Infrastructure${NC}"
    echo "================================="
    
    if [[ -f "$DEMO_DIR/docker-compose.demo.yml" ]]; then
        cd "$DEMO_DIR"
        echo "Starting Kafka and related services..."
        docker-compose -f docker-compose.demo.yml up -d --quiet-pull
        
        echo "Waiting for Kafka to be ready..."
        sleep 10
        
        # Verify Kafka is running
        if docker-compose -f docker-compose.demo.yml ps | grep -q "Up"; then
            print_status "Kafka infrastructure started"
        else
            print_warning "Kafka may not be fully ready yet"
        fi
    else
        print_warning "docker-compose.demo.yml not found. Skipping Kafka setup."
        SKIP_KAFKA=true
    fi
fi

# Demo execution options
echo -e "\n${BLUE}🎯 Demo Execution Options${NC}"
echo "=========================="
echo "Choose which demo to run:"
echo "1. File Processing Only (Rust API)"  
echo "2. SQL Interface Demo"
echo "3. Complete Pipeline with Kafka"
echo "4. All Demos (sequential)"
echo ""

while true; do
    read -p "Enter choice [1-4]: " choice
    case $choice in
        [1-4]) break;;
        *) echo "Please enter 1, 2, 3, or 4";;
    esac
done

cd "$DEMO_DIR/../.."  # Back to project root

# Execute chosen demo
case $choice in
    1)
        echo -e "\n${BLUE}🔧 Running File Processing Demo (Rust API)${NC}"
        echo "==========================================="
        echo "This demo shows:"
        echo "• Reading CSV files with FileDataSource"
        echo "• Processing with exact ScaledInteger arithmetic"  
        echo "• Writing to compressed JSON files with FileSink"
        echo "• Real-time file watching and rotation"
        echo ""
        RUSTFLAGS="-A dead_code" cargo run --bin file_processing_demo --no-default-features
        ;;
        
    2)
        echo -e "\n${BLUE}💾 Running SQL Interface Demo${NC}" 
        echo "============================="
        echo "This demo shows:"
        echo "• SQL streams and tables from CSV files"
        echo "• Real-time windowed aggregations"
        echo "• Financial precision with DECIMAL types"
        echo "• Complex joins and analytics"
        echo ""
        echo "Starting FerrisStreams SQL server..."
        echo "After server starts, run the SQL commands in enhanced_sql_demo.sql"
        echo "Or use: ferris-sql --file ./demo/datasource-demo/enhanced_sql_demo.sql"
        echo ""
        RUSTFLAGS="-A dead_code" cargo run --bin ferris-sql --no-default-features -- server
        ;;
        
    3)
        if [[ "$SKIP_KAFKA" == "true" ]]; then
            print_error "Kafka not available. Please install Docker or choose a different demo."
            exit 1
        fi
        
        echo -e "\n${BLUE}🌊 Running Complete Pipeline Demo${NC}"
        echo "================================="
        echo "This demo shows:"
        echo "• File → Kafka → Processing → File pipeline"
        echo "• Cross-system data serialization with Avro"
        echo "• High-throughput streaming with backpressure"
        echo "• Production-ready error handling"
        echo ""
        RUSTFLAGS="-A dead_code" cargo run --bin complete_pipeline_demo         ;;
        
    4)
        echo -e "\n${BLUE}🎪 Running All Demos${NC}"
        echo "=================="
        
        echo -e "\n${YELLOW}Demo 1: File Processing${NC}"
        timeout 30s RUSTFLAGS="-A dead_code" cargo run --bin file_processing_demo --no-default-features || true
        
        if [[ "$SKIP_KAFKA" != "true" ]]; then
            echo -e "\n${YELLOW}Demo 2: Complete Pipeline${NC}"  
            timeout 30s RUSTFLAGS="-A dead_code" cargo run --bin complete_pipeline_demo || true
        fi
        
        echo -e "\n${YELLOW}Demo 3: SQL Interface${NC}"
        echo "SQL server will start for interactive use..."
        RUSTFLAGS="-A dead_code" cargo run --bin ferris-sql --no-default-features -- server
        ;;
esac

# Show results
echo -e "\n${BLUE}📊 Demo Results${NC}"
echo "==============="

if [[ -d "$OUTPUT_DIR" ]]; then
    echo "Output files created:"
    find "$OUTPUT_DIR" -type f -exec ls -lh {} \; 2>/dev/null | head -10
    
    if [[ -f "$OUTPUT_DIR/processed_transactions.jsonl" ]]; then
        PROCESSED_COUNT=$(wc -l < "$OUTPUT_DIR/processed_transactions.jsonl")
        print_status "Processed $PROCESSED_COUNT transaction records"
    fi
fi

# Performance summary
echo -e "\n${BLUE}⚡ Performance Highlights${NC}"  
echo "========================"
echo "• ScaledInteger arithmetic: Exact precision with optimized performance"
echo "• Exact financial precision: No rounding errors in calculations"
echo "• Real-time processing: Sub-millisecond latency per record"
echo "• File watching: Automatic processing of new data"
echo "• Compression: Reduced storage with gzip/snappy"

# Cleanup option
echo -e "\n${BLUE}🧹 Cleanup${NC}"
echo "========="
read -p "Clean up demo data and stop services? [y/N]: " cleanup

if [[ $cleanup =~ ^[Yy]$ ]]; then
    echo "Cleaning up..."
    
    # Stop Kafka
    if [[ "$SKIP_KAFKA" != "true" && -f "$DEMO_DIR/docker-compose.demo.yml" ]]; then
        cd "$DEMO_DIR"
        docker-compose -f docker-compose.demo.yml down -v --quiet
        print_status "Kafka services stopped"
    fi
    
    # Clean demo files
    if [[ -d "$OUTPUT_DIR" ]]; then
        rm -rf "$OUTPUT_DIR"
        print_status "Output directory cleaned"
    fi
    
    print_status "Cleanup completed"
else
    echo "Demo artifacts preserved in:"
    echo "• Data: $DATA_DIR"  
    echo "• Output: $OUTPUT_DIR"
    echo "• Configs: $CONFIG_DIR"
    
    if [[ "$SKIP_KAFKA" != "true" ]]; then
        echo ""
        echo "To stop Kafka later:"
        echo "cd $DEMO_DIR && docker-compose -f docker-compose.demo.yml down -v"
    fi
fi

echo -e "\n${GREEN}🎉 Demo completed successfully!${NC}"
echo ""
echo "Key takeaways:"
echo "• FerrisStreams provides exact precision for financial calculations"  
echo "• Supports both Rust API and SQL interfaces for flexibility"
echo "• Production-ready with file watching, rotation, compression, and error handling"
echo "• Seamlessly integrates with Kafka for real-time streaming architectures"
echo ""
echo "For more information, see:"  
echo "• README.md for detailed documentation"
echo "• enhanced_sql_demo.sql for advanced SQL examples"
echo "• configs/ for configuration templates"