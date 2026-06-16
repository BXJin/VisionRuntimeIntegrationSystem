# State, async, and error handling

## 목적

실무형 통합 시스템에서 가장 중요한 것은 기능이 한 번 동작하는 것이 아니라, 지연과 실패가 있어도 상태가 무너지지 않는 것이다.

## 핵심 상태

```text
Idle
Capturing
Encoding
Uploading
WaitingInference
Completed
Failed
Cancelled
Timeout
```

## request id

모든 요청은 request id를 가진다.

```text
vision_yyyyMMdd_HHmmss_random
```

용도:

- client/server metric join
- stale response 차단
- 로그 추적
- benchmark 결과 그룹화
- retry와 원본 요청 연결

## timeout

timeout은 하나가 아니라 구간별로 둔다.

| 구간 | 예시 timeout | 실패 처리 |
|---|---:|---|
| capture | 1s | input failure |
| encode | 1s | input failure |
| upload | 3s | network failure |
| inference | 2s | provider timeout |
| total | 5s | request timeout |

실제 값은 측정 후 조정한다.

## stale response

문제:

```text
A 요청 전송
B 요청 전송
B 응답 적용
A 응답 늦게 도착
```

정책:

```text
if response.requestId != activeRequestId:
    ignore
    log stale_response=true
```

## retry

무조건 재시도하지 않는다.

| 실패 | retry |
|---|---|
| network timeout | 1회 가능 |
| 429/503 | backoff 후 1회 가능 |
| invalid image | retry 없음 |
| schema validation 실패 | repair 또는 fallback |
| model unavailable | provider fallback |

## cancel

C++ client에서 cancel은 다음을 의미한다.

- client callback 적용 중단
- active request id 무효화
- server job 취소 요청 가능하면 전송
- 늦게 도착한 response 무시

초기에는 서버 job cancel까지 구현하지 않아도 된다. client-side cancel과 stale guard부터 구현한다.

## error taxonomy

| errorType | 위치 | 설명 |
|---|---|---|
| invalid_image | server | decode 실패 |
| too_large | server | 파일 크기 초과 |
| unsupported_format | server | 포맷 미지원 |
| provider_unavailable | server | 모델/provider 없음 |
| inference_timeout | server | 추론 지연 |
| network_timeout | client | 요청 timeout |
| stale_response | client | 오래된 응답 |
| json_parse_error | client | 응답 contract 불일치 |

## fallback

초기 fallback:

- CUDA 실패 -> CPU provider
- model unavailable -> mock disabled error
- inference timeout -> error response
- stale response -> ignore

실서비스 fallback:

- 마지막 정상 결과 유지
- degraded mode
- 사용자에게 "분석 실패" 표시
- retry button

## metric join

client CSV:

```text
request_id, upload_ms, round_trip_ms, json_parse_ms, total_client_ms
```

server CSV:

```text
request_id, decode_ms, preprocess_ms, inference_ms, total_server_ms
```

join 후:

```text
end_to_end_ms = total_client_ms
server_ratio = total_server_ms / total_client_ms
network_client_overhead = total_client_ms - total_server_ms
```

## 면접용 답변

> 단순히 서버가 JSON을 반환하는 것보다, C++ client와 Python gateway 사이의 상태를 안전하게 관리하는 것이 중요하다고 봤습니다. 모든 요청에 request id를 두고, timeout, cancel, stale response, retry 가능 오류와 불가능 오류를 구분했습니다. 서버 metric과 client metric은 request id로 join해서 모델 지연과 클라이언트 통합 비용을 분리해 볼 수 있게 설계했습니다.

