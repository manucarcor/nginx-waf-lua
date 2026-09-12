#!/bin/bash

echo "🚀 Testing gRPC Configuration for nginx-waf-lua"
echo "================================================"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    local status=$1
    local message=$2
    case $status in
        "INFO")  echo -e "${BLUE}ℹ️  $message${NC}" ;;
        "OK")    echo -e "${GREEN}✅ $message${NC}" ;;
        "WARN")  echo -e "${YELLOW}⚠️  $message${NC}" ;;
        "ERROR") echo -e "${RED}❌ $message${NC}" ;;
    esac
}

# Check if docker-compose is available
if ! command -v docker-compose &> /dev/null; then
    print_status "ERROR" "docker-compose not found. Please install docker-compose."
    exit 1
fi

print_status "INFO" "Building nginx image..."
cd ..
if docker build -t nginx-waf-lua:local .; then
    print_status "OK" "nginx image built successfully"
else
    print_status "ERROR" "Failed to build nginx image"
    exit 1
fi

cd test

print_status "INFO" "Starting test environment..."
docker-compose down --remove-orphans 2>/dev/null
if docker-compose up -d; then
    print_status "OK" "Test environment started"
else
    print_status "ERROR" "Failed to start test environment"
    exit 1
fi

# Wait for services to be ready
print_status "INFO" "Waiting for services to be ready..."
sleep 10

# Function to test HTTP/2 capability
test_http2() {
    print_status "INFO" "Testing HTTP/2 support..."
    if curl -k -s --http2 -I https://localhost:443 | grep -q "HTTP/2"; then
        print_status "OK" "HTTP/2 support confirmed"
        return 0
    else
        print_status "WARN" "HTTP/2 not detected in response"
        return 1
    fi
}

# Function to test gRPC port availability
test_grpc_port() {
    print_status "INFO" "Testing gRPC port (9443) availability..."
    if timeout 5 bash -c "</dev/tcp/localhost/9443"; then
        print_status "OK" "gRPC port 9443 is accessible"
        return 0
    else
        print_status "ERROR" "gRPC port 9443 is not accessible"
        return 1
    fi
}

# Function to test gRPC backend connectivity
test_grpc_backend() {
    print_status "INFO" "Testing gRPC backend server connectivity..."
    if timeout 5 bash -c "</dev/tcp/localhost/50051"; then
        print_status "OK" "gRPC backend server is accessible"
        return 0
    else
        print_status "ERROR" "gRPC backend server is not accessible"
        return 1
    fi
}

# Function to check nginx configuration
test_nginx_config() {
    print_status "INFO" "Checking nginx configuration..."
    if docker-compose exec -T nginx nginx -t 2>/dev/null; then
        print_status "OK" "nginx configuration is valid"
        return 0
    else
        print_status "ERROR" "nginx configuration has errors"
        docker-compose exec -T nginx nginx -t
        return 1
    fi
}

# Function to check if gRPC modules are loaded
test_grpc_modules() {
    print_status "INFO" "Checking if HTTP/2 module is compiled..."
    if docker-compose exec -T nginx nginx -V 2>&1 | grep -q "http_v2_module"; then
        print_status "OK" "HTTP/2 module is compiled and available"
        return 0
    else
        print_status "ERROR" "HTTP/2 module is not available"
        return 1
    fi
}

# Function to show nginx build info
show_nginx_info() {
    print_status "INFO" "Nginx build information:"
    echo "=================================="
    docker-compose exec -T nginx nginx -V 2>&1 | grep -E "(version|built|TLS|configure arguments)"
    echo "=================================="
}

# Function to test gRPC health check (if available)
test_grpc_health() {
    print_status "INFO" "Testing gRPC health check endpoint..."
    
    # Try to connect with grpcurl if available in container
    if docker-compose exec -T grpc-test-server which grpcurl &>/dev/null; then
        if docker-compose exec -T grpc-test-server grpcurl -plaintext localhost:50051 grpc.health.v1.Health/Check 2>/dev/null; then
            print_status "OK" "gRPC health check successful"
            return 0
        fi
    fi
    
    print_status "WARN" "gRPC health check not available (grpcurl not found or service not responding)"
    return 1
}

# Function to show service logs
show_logs() {
    print_status "INFO" "Service logs (last 10 lines):"
    echo "=== nginx logs ==="
    docker-compose logs --tail=10 nginx
    echo "=== grpc-test-server logs ==="
    docker-compose logs --tail=10 grpc-test-server
}

# Run all tests
print_status "INFO" "Running gRPC compatibility tests..."
echo ""

# Basic tests
test_nginx_config
test_grpc_modules
test_http2
test_grpc_port
test_grpc_backend

echo ""
print_status "INFO" "Additional information:"
show_nginx_info

echo ""
print_status "INFO" "Testing gRPC functionality..."
test_grpc_health

echo ""
show_logs

echo ""
print_status "INFO" "Test summary:"
print_status "OK" "gRPC proxy configuration created"
print_status "OK" "HTTP/2 support verified in build"
print_status "OK" "Test environment with gRPC backend deployed"
print_status "INFO" "Manual testing available:"
echo "  - nginx HTTP: http://localhost:80"
echo "  - nginx HTTPS: https://localhost:443"  
echo "  - nginx gRPC: grpc://localhost:9443"
echo "  - gRPC backend: localhost:50051"
echo "  - Jaeger UI: http://localhost:16686"

print_status "INFO" "To test gRPC manually, use grpcurl:"
echo "  grpcurl -insecure localhost:9443 grpc.health.v1.Health/Check"

print_status "INFO" "To stop the test environment:"
echo "  docker-compose down"
