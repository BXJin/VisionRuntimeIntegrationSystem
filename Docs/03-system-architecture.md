# System architecture

## 목적

Vision Runtime Integration System의 전체 구조와 컴포넌트 책임을 정의한다.

## 전체 구조

```text
Input Sources
  - image file
  - mobile browser still capture
  - USB webcam
  - future camera/device SDK

        |
        v

C++ Runtime Integration Client
  - request id / job id
  - image encode / upload
  - async HTTP or WebSocket
  - timeout / cancel
  - stale response guard
  - JSON parsing
  - client metrics
  - callback/event API

        |
        v

Python Vision Inference Gateway
  - FastAPI endpoint
  - request validation
  - OpenCV preprocessing
  - inference provider routing
  - result contract validation
  - server metrics
  - health check

        |
        v

Inference Providers
  - MockProvider
  - OnnxRuntimeCpuProvider
  - OnnxRuntimeCudaProvider
  - Future TritonProvider

        |
        v

Result Consumers
  - C++ console output
  - desktop UI
  - Unreal/PromptMotionLab extension
  - ops dashboard / benchmark report
```

## 컴포넌트 책임

| 컴포넌트 | 책임 | 책임지지 않는 것 |
|---|---|---|
| C++ Runtime Client | 입력 수집, 비동기 요청, 상태/수명/timeout, 결과 적용 | 모델 추론, provider 선택 |
| Python Gateway | API, 전처리, provider 호출, 서버 metric | UI 상태, client lifecycle |
| OpenCV Preprocessor | decode, resize, color conversion, tensor 변환 | 모델 실행 |
| ONNX Provider | inference session, CPU/CUDA provider | 요청 검증, 파일 업로드 |
| Metrics Logger | 구간별 latency 기록 | 통계 해석 자동화 전체 |
| Benchmark Runner | 반복 요청, p50/p95 계산 | production traffic 생성 |

## 핵심 데이터 계약

### Request

```json
{
  "requestId": "vision_20260616_0001",
  "source": "file|mobile|webcam|device_sdk",
  "model": "mobilenetv3",
  "provider": "cpu|cuda|triton",
  "image": "multipart file"
}
```

### Response

```json
{
  "requestId": "vision_20260616_0001",
  "status": "ok",
  "model": "mobilenetv3",
  "provider": "cpu",
  "predictions": [
    { "label": "camera", "score": 0.81 },
    { "label": "tripod", "score": 0.09 }
  ],
  "serverLatencyMs": {
    "decode": 4.2,
    "preprocess": 2.7,
    "inference": 18.4,
    "postprocess": 0.6,
    "total": 29.1
  }
}
```

### Error

```json
{
  "requestId": "vision_20260616_0001",
  "status": "error",
  "errorType": "invalid_image|too_large|model_unavailable|timeout",
  "message": "Invalid image input."
}
```

## 배포 형태

### Local development

```text
C++ console client
-> localhost FastAPI
-> ONNX Runtime CPU
-> CSV files
```

### GPU workstation

```text
C++ client
-> FastAPI
-> ONNX Runtime CUDA
-> GPU metrics
```

### Future server split

```text
C++ client
-> API Gateway
-> Vision Inference Gateway
-> Triton Inference Server
-> Metrics/Logs
```

## 왜 이 구조인가

- C++과 Python의 강점을 분리한다.
- 모델 추론 provider를 바꿔도 client contract를 유지한다.
- camera input source를 바꿔도 inference gateway를 유지한다.
- 성능 병목을 client, network, server, model로 나눌 수 있다.
- 면접에서 "어디까지 직접 구현했고 어디가 확장 계획인지"를 명확히 말할 수 있다.

## 가장 중요한 설계 원칙

1. C++ client는 절대 응답을 동기 대기하지 않는다.
2. 모든 요청은 request id를 가진다.
3. 서버 metric과 client metric은 request id로 합칠 수 있어야 한다.
4. GPU 사용 여부는 기능 flag가 아니라 측정 결과로 판단한다.
5. 모델 output은 raw 배열이 아니라 typed result contract로 변환한다.

