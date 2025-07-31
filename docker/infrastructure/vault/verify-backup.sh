#!/bin/bash

# Backup System Verification Script
# Verifies that all backup components are working correctly

echo "🔍 Infrastructure Backup System Verification"
echo "============================================="

# Check if we're in the right directory
cd /home/bookchaowalit/book/book_docker/vault

PASSED=0
FAILED=0

# Test 1: Check if Vault is accessible
echo ""
echo "Test 1: Vault Accessibility"
if curl -s http://vault.localhost/v1/sys/health > /dev/null; then
    echo "✅ PASS - Vault is accessible at http://vault.localhost"
    ((PASSED++))
else
    echo "❌ FAIL - Vault is not accessible"
    ((FAILED++))
fi

# Test 2: Check if Docker is running
echo ""
echo "Test 2: Docker Status"
if docker info > /dev/null 2>&1; then
    echo "✅ PASS - Docker is running"
    ((PASSED++))
else
    echo "❌ FAIL - Docker is not running"
    ((FAILED++))
fi

# Test 3: Check if all scripts are executable
echo ""
echo "Test 3: Script Permissions"
SCRIPTS=("vault-manager.sh" "complete-backup.sh" "backup-volumes.sh" "get-secrets.sh" "init-vault.sh")
ALL_EXECUTABLE=true

for script in "${SCRIPTS[@]}"; do
    if [ -x "$script" ]; then
        echo "✅ $script is executable"
    else
        echo "❌ $script is not executable"
        ALL_EXECUTABLE=false
    fi
done

if $ALL_EXECUTABLE; then
    echo "✅ PASS - All scripts are executable"
    ((PASSED++))
else
    echo "❌ FAIL - Some scripts are not executable"
    ((FAILED++))
fi

# Test 4: Check backup directory permissions
echo ""
echo "Test 4: Backup Directory"
BACKUP_DIR="/home/bookchaowalit/book/book_docker/backups"
if [ -d "$BACKUP_DIR" ] && [ -w "$BACKUP_DIR" ]; then
    echo "✅ PASS - Backup directory exists and is writable"
    ((PASSED++))
else
    echo "❌ FAIL - Backup directory issues"
    mkdir -p "$BACKUP_DIR" 2>/dev/null && echo "✅ Created backup directory"
    ((FAILED++))
fi

# Test 5: Check disk space
echo ""
echo "Test 5: Disk Space"
AVAILABLE=$(df "$BACKUP_DIR" --output=avail | tail -1)
if [ "$AVAILABLE" -gt 5242880 ]; then  # 5GB in KB
    echo "✅ PASS - Sufficient disk space ($(echo "$AVAILABLE" | awk '{print int($1/1024/1024)"GB"}')+)"
    ((PASSED++))
else
    echo "⚠️  WARNING - Low disk space ($(echo "$AVAILABLE" | awk '{print int($1/1024/1024)"GB"}'))"
    ((FAILED++))
fi

# Test 6: Test vault secrets retrieval
echo ""
echo "Test 6: Vault Secrets Access"
if ./get-secrets.sh twenty > /dev/null 2>&1; then
    echo "✅ PASS - Can retrieve secrets from Vault"
    ((PASSED++))
else
    echo "❌ FAIL - Cannot retrieve secrets from Vault"
    ((FAILED++))
fi

# Test 7: Count Docker volumes
echo ""
echo "Test 7: Docker Volumes"
VOLUME_COUNT=$(docker volume ls --format "{{.Name}}" | grep -E "^[a-zA-Z]" | wc -l)
if [ "$VOLUME_COUNT" -gt 0 ]; then
    echo "✅ PASS - Found $VOLUME_COUNT named Docker volumes to backup"
    ((PASSED++))
else
    echo "❌ FAIL - No named Docker volumes found"
    ((FAILED++))
fi

# Test 8: Test Airflow DAG syntax (if Python is available)
echo ""
echo "Test 8: Airflow DAG Syntax"
if command -v python3 > /dev/null 2>&1; then
    if python3 -m py_compile airflow_backup_dag.py 2>/dev/null; then
        echo "✅ PASS - Airflow DAG syntax is valid"
        ((PASSED++))
    else
        echo "⚠️  WARNING - Airflow DAG syntax issues (check manually)"
        ((FAILED++))
    fi
else
    echo "⚠️  SKIP - Python3 not available for DAG syntax check"
fi

# Summary
echo ""
echo "=========================================="
echo "📊 Verification Summary"
echo "=========================================="
echo "✅ Tests Passed: $PASSED"
echo "❌ Tests Failed: $FAILED"
echo ""

if [ $FAILED -eq 0 ]; then
    echo "🎉 ALL TESTS PASSED!"
    echo "Your backup system is ready for production!"
    echo ""
    echo "Next steps:"
    echo "1. Deploy Airflow DAG: cp airflow_backup_dag.py /path/to/airflow/dags/"
    echo "2. Configure email settings in the DAG"
    echo "3. Enable the DAG in Airflow UI"
    echo "4. Test with: ./vault-manager.sh backup-complete"
else
    echo "⚠️  SOME TESTS FAILED"
    echo "Please fix the failing tests before deploying to production."
    echo ""
    echo "Common fixes:"
    echo "- Start Vault: cd /home/bookchaowalit/book/book_docker/vault && docker-compose up -d"
    echo "- Fix permissions: chmod +x *.sh"
    echo "- Free disk space: clean up old files"
fi

echo ""
echo "For manual testing, run:"
echo "  ./vault-manager.sh backup-complete"
