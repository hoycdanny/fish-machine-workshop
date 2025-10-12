#!/bin/bash

# API 測試腳本
# 用於測試各個微服務的 API 端點

echo "🧪 開始 API 功能測試..."
echo "========================"

# 顏色定義
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 測試計數器
total_tests=0
passed_tests=0

# 測試函數
test_api() {
    local test_name=$1
    local method=$2
    local url=$3
    local data=$4
    local expected_field=$5
    local expected_value=$6
    
    ((total_tests++))
    echo -n "測試 $test_name... "
    
    if [ "$method" = "GET" ]; then
        response=$(curl -s -w "%{http_code}" -o /tmp/api_response.json "$url" 2>/dev/null)
    else
        response=$(curl -s -X "$method" "$url" \
            -H "Content-Type: application/json" \
            -d "$data" \
            -w "%{http_code}" \
            -o /tmp/api_response.json 2>/dev/null)
    fi
    
    http_code="${response: -3}"
    
    if [ "$http_code" = "200" ]; then
        if [ -n "$expected_field" ] && [ -n "$expected_value" ]; then
            actual_value=$(cat /tmp/api_response.json | grep -o "\"$expected_field\":[^,}]*" | cut -d':' -f2 | tr -d '"' | tr -d ' ')
            if [ "$actual_value" = "$expected_value" ]; then
                echo -e "${GREEN}✅ 通過${NC}"
                ((passed_tests++))
                return 0
            else
                echo -e "${YELLOW}⚠️  回應異常 ($expected_field: $actual_value != $expected_value)${NC}"
                return 1
            fi
        else
            echo -e "${GREEN}✅ 通過${NC}"
            ((passed_tests++))
            return 0
        fi
    else
        echo -e "${RED}❌ 失敗 (HTTP: $http_code)${NC}"
        if [ -f /tmp/api_response.json ]; then
            echo -e "${RED}   回應: $(cat /tmp/api_response.json)${NC}"
        fi
        return 1
    fi
}

# 生成唯一的測試用戶名
TEST_USER="testuser_$(date +%s)"
TEST_PASS="testpass123"

echo ""
echo -e "${BLUE}🏥 健康檢查 API 測試${NC}"
echo "----------------------"

test_api "Client Service 健康檢查" "GET" "http://localhost:8080/health" "" "service" "client-service"
test_api "Game Session Service 健康檢查" "GET" "http://localhost:8082/health" "" "service" "game-session-service"
test_api "Game Server Service 健康檢查" "GET" "http://localhost:8083/health" "" "service" "game-server-service"

echo ""
echo -e "${BLUE}👤 用戶管理 API 測試${NC}"
echo "--------------------"

# 用戶註冊
test_api "用戶註冊" "POST" "http://localhost:8082/api/v1/users/register" \
    "{\"username\":\"$TEST_USER\",\"password\":\"$TEST_PASS\"}" "success" "true"

# 用戶登入
test_api "用戶登入" "POST" "http://localhost:8082/api/v1/users/login" \
    "{\"username\":\"$TEST_USER\",\"password\":\"$TEST_PASS\"}" "success" "true"

# 重複註冊 (應該失敗)
echo -n "測試重複註冊 (預期失敗)... "
response=$(curl -s -X POST "http://localhost:8082/api/v1/users/register" \
    -H "Content-Type: application/json" \
    -d "{\"username\":\"$TEST_USER\",\"password\":\"$TEST_PASS\"}" \
    -w "%{http_code}" \
    -o /tmp/api_response.json 2>/dev/null)
http_code="${response: -3}"
if [ "$http_code" = "400" ]; then
    echo -e "${GREEN}✅ 正確拒絕${NC}"
    ((passed_tests++))
else
    echo -e "${RED}❌ 應該拒絕重複註冊${NC}"
fi
((total_tests++))

echo ""
echo -e "${BLUE}🏠 大廳管理 API 測試${NC}"
echo "--------------------"

# 獲取房間列表
test_api "獲取房間列表" "GET" "http://localhost:8082/api/v1/lobby/rooms" "" "success" "true"

# 創建房間
TEST_ROOM_NAME="測試房間_$(date +%s)"
test_api "創建房間" "POST" "http://localhost:8082/api/v1/lobby/rooms/create" \
    "{\"name\":\"$TEST_ROOM_NAME\",\"maxPlayers\":4}" "success" "true"

# 提取房間 ID (用於後續測試)
if [ -f /tmp/api_response.json ]; then
    ROOM_ID=$(cat /tmp/api_response.json | grep -o '"roomId":"[^"]*"' | cut -d'"' -f4)
    echo "   📝 創建的房間 ID: $ROOM_ID"
fi

# 加入房間 (如果有房間 ID)
if [ -n "$ROOM_ID" ]; then
    test_api "加入房間" "POST" "http://localhost:8082/api/v1/lobby/rooms/$ROOM_ID/join" \
        "{\"userId\":\"user_123\",\"username\":\"TestPlayer\"}" "success" "true"
    
    # 離開房間
    test_api "離開房間" "POST" "http://localhost:8082/api/v1/lobby/rooms/$ROOM_ID/leave" \
        "{\"userId\":\"user_123\"}" "success" "true"
fi

echo ""
echo -e "${BLUE}🎮 遊戲邏輯 API 測試${NC}"
echo "--------------------"

if [ -n "$ROOM_ID" ]; then
    # 開始遊戲
    test_api "開始遊戲" "POST" "http://localhost:8083/api/v1/game/start" \
        "{\"roomId\":\"$ROOM_ID\",\"userId\":\"user_123\"}" "success" "true"
    
    # 發射子彈
    test_api "發射子彈" "POST" "http://localhost:8083/api/v1/game/shoot" \
        "{\"roomId\":\"$ROOM_ID\",\"userId\":\"user_123\",\"x\":100,\"y\":100,\"targetX\":200,\"targetY\":200}" "success" "true"
    
    # 獲取房間狀態
    test_api "獲取房間狀態" "GET" "http://localhost:8083/api/v1/game/room/$ROOM_ID/state" "" "success" "true"
else
    echo -e "${YELLOW}⚠️  跳過遊戲 API 測試 (沒有可用的房間 ID)${NC}"
fi

echo ""
echo -e "${BLUE}📊 管理後台 API 測試${NC}"
echo "----------------------"

# 遊戲統計
test_api "遊戲統計" "GET" "http://localhost:8083/admin/api/stats" "" "success" "true"

# 遊戲配置
test_api "獲取遊戲配置" "GET" "http://localhost:8083/admin/api/config" "" "success" "true"

# 用戶列表
test_api "獲取用戶列表" "GET" "http://localhost:8082/admin/users" "" "success" "true"

echo ""
echo -e "${BLUE}🧹 清理測試數據${NC}"
echo "------------------"

# 清理測試用戶
echo -n "清理測試用戶... "
cleanup_response=$(curl -s -X POST "http://localhost:8082/admin/delete-user" \
    -H "Content-Type: application/json" \
    -d "{\"username\":\"$TEST_USER\"}" \
    -w "%{http_code}" \
    -o /tmp/cleanup_response.json 2>/dev/null)
cleanup_code="${cleanup_response: -3}"
if [ "$cleanup_code" = "200" ]; then
    echo -e "${GREEN}✅ 完成${NC}"
else
    echo -e "${YELLOW}⚠️  部分清理失敗${NC}"
fi

# 清理測試房間 (如果有)
if [ -n "$ROOM_ID" ]; then
    echo -n "清理測試房間... "
    room_cleanup=$(curl -s -X POST "http://localhost:8082/admin/delete-room" \
        -H "Content-Type: application/json" \
        -d "{\"roomId\":\"$ROOM_ID\"}" \
        -w "%{http_code}" \
        -o /tmp/room_cleanup.json 2>/dev/null)
    room_cleanup_code="${room_cleanup: -3}"
    if [ "$room_cleanup_code" = "200" ]; then
        echo -e "${GREEN}✅ 完成${NC}"
    else
        echo -e "${YELLOW}⚠️  部分清理失敗${NC}"
    fi
fi

echo ""
echo "📊 測試總結"
echo "============"
echo "總測試數: $total_tests"
echo "通過測試: $passed_tests"
echo "失敗測試: $((total_tests - passed_tests))"

if [ $passed_tests -eq $total_tests ]; then
    echo -e "${GREEN}🎉 所有 API 測試通過！${NC}"
    exit 0
else
    success_rate=$((passed_tests * 100 / total_tests))
    echo -e "${YELLOW}⚠️  成功率: $success_rate%${NC}"
    
    if [ $success_rate -ge 80 ]; then
        echo -e "${YELLOW}大部分功能正常，建議檢查失敗的測試項目${NC}"
        exit 1
    else
        echo -e "${RED}多項測試失敗，建議檢查服務配置和日誌${NC}"
        exit 2
    fi
fi

# 清理臨時文件
rm -f /tmp/api_response.json /tmp/cleanup_response.json /tmp/room_cleanup.json