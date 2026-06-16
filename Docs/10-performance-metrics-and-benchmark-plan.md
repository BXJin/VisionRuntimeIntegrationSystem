# Performance metrics and benchmark plan

## 목적

이 프로젝트는 성능 수치가 핵심이다. 단순히 "동작한다"가 아니라 어디서 지연이 생기는지 구간별로 측정해야 한다.

## 적용 전/후 비교

### 적용 전

```text
이미지 입력을 AI 추론 서비스로 연결하는 구조 없음
또는 Python 단일 script로만 추론
```

한계:

- client upload 비용을 알 수 없음
- decode/preprocess/inference 구분 불가
- C++ runtime integration 비용 확인 불가
- p50/p95 기준 없음
- failure type 분류 없음

### 적용 후

```text
C++ runtime client
-> Python inference gateway
-> OpenCV preprocessing
-> ONNX Runtime provider
-> result contract
-> client/server metrics
```

개선:

- end-to-end latency 측정 가능
- client/server 병목 분리
- CPU/CUDA provider 비교 가능
- input source별 성능 비교 가능
- 실패 유형별 통계 가능

## 측정 항목

### client metrics

```text
capture_ms
encode_ms
upload_ms
round_trip_ms
json_parse_ms
total_client_ms
timeout_count
stale_response_count
```

### server metrics

```text
request_read_ms
decode_ms
preprocess_ms
inference_ms
postprocess_ms
total_server_ms
success
error_type
provider
model
```

### joined metrics

```text
end_to_end_ms
server_ratio
client_overhead_ms
network_or_transport_ms
```

## benchmark scenarios

### B1. baseline single image

목표:

- 단일 이미지 100회 요청
- p50/p95 산출

결과:

```text
total_client_ms p50
total_client_ms p95
server_total_ms p50
inference_ms p50
fail_rate
```

### B2. image size comparison

입력:

```text
640x480
1280x720
1920x1080
3840x2160
```

관찰:

- decode_ms 증가
- preprocess_ms 증가
- upload_ms 증가
- inference_ms는 대체로 동일

### B3. provider comparison

```text
CPU vs CUDA
```

관찰:

- inference_ms
- total_server_ms
- cold start
- p95

판단:

GPU가 inference_ms를 줄여도 total_server_ms가 줄지 않으면 실효성이 낮다.

### B4. model comparison

```text
MobileNetV3 vs ResNet18
```

관찰:

- model size
- load time
- inference_ms
- top1 confidence

### B5. concurrency

```text
concurrency 1 / 5 / 10
```

관찰:

- throughput
- p50
- p95
- timeout_count

### B6. C++ vs Python client

목표:

Python benchmark와 C++ client의 overhead 비교.

관찰:

- upload_ms
- json_parse_ms
- round_trip_ms
- total_client_ms

## 결과 문서 양식

```text
## Benchmark result - YYYY-MM-DD

Environment:
- CPU:
- GPU:
- OS:
- Python:
- ONNX Runtime:
- Model:

Scenario:
- B1 baseline 100 requests

Result:
- total_client_ms p50:
- total_client_ms p95:
- total_server_ms p50:
- inference_ms p50:
- fail_rate:

Finding:
- 병목:
- 다음 개선:
```

## 성공 기준

| 지표 | 목표 |
|---|---:|
| invalid image 500 발생 | 0건 |
| request id 누락 | 0건 |
| baseline 100회 fail rate | 1% 이하 |
| server metric 기록률 | 100% |
| client metric 기록률 | 100% |
| p50/p95 산출 가능 | 가능 |

수치 목표는 초기 측정 후 현실적으로 조정한다. 처음부터 latency 목표를 고정하면 환경 차이 때문에 의미가 약해진다.

## 면접용 답변

> 이 프로젝트에서는 성능을 평균 하나로 보지 않고 client capture/encode/upload, server decode/preprocess/inference/postprocess로 나눠 측정합니다. C++ client와 Python server의 CSV를 request id로 join해서 모델이 느린지, 이미지 전송이 느린지, JSON parsing이나 client callback 비용이 큰지 구분할 수 있게 설계했습니다.

