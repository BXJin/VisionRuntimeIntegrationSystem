# Inference provider and GPU scaling

## 목적

AI 추론을 외부 API가 아니라 local model serving 관점에서 다루기 위해 provider 구조, CPU/CUDA 비교, Triton 확장 기준을 정의한다.

## provider 단계

```text
MockProvider
-> OnnxRuntimeCpuProvider
-> OnnxRuntimeCudaProvider
-> TensorRT(optional)
-> TritonProvider
```

## MockProvider

용도:

- API contract 테스트
- C++ client 연동 테스트
- latency logging 테스트
- 모델 파일 없이 개발 가능

응답:

```json
{
  "predictions": [
    { "label": "mock_object", "score": 0.99 }
  ]
}
```

## ONNX Runtime CPU

첫 baseline이다.

장점:

- 설치가 쉽다.
- GPU 없이 동작한다.
- 모델 입력/출력 계약을 고정하기 좋다.

측정:

- first inference latency
- warmed p50/p95
- memory usage
- model load time

## ONNX Runtime CUDA

GPU 비교 단계다.

주의:

- GPU가 항상 빠르지 않다.
- 작은 모델은 CPU가 더 빠를 수 있다.
- provider 초기화와 CPU/GPU memory copy 비용을 봐야 한다.

측정:

- first inference
- warm-up 이후 p50/p95
- total_server_ms
- inference_ms
- GPU utilization
- GPU memory

## TensorRT

후순위다.

사용 시점:

- ONNX Runtime CUDA로도 latency가 부족할 때
- 모델이 고정되어 있고 최적화 비용을 감당할 때
- 배포 환경의 NVIDIA stack이 안정되어 있을 때

이번 문서에서는 설계만 남긴다.

## Triton Provider

Triton은 모델을 서버 형태로 올려 여러 클라이언트가 안정적으로 호출하게 해주는 inference server다.

적합한 시점:

- 직접 보유한 모델이 있다.
- 여러 모델 version을 관리해야 한다.
- GPU worker를 따로 운영해야 한다.
- batching, concurrency, model warm-up이 필요하다.
- API gateway와 inference server를 분리해야 한다.

부적합한 시점:

- 외부 OpenAI/Azure API가 병목이다.
- 자체 모델이 없다.
- 단일 사용자 local PoC다.
- 설치/운영 복잡도가 학습 효과보다 크다.

## provider routing

```text
requested provider
-> available?
   yes -> use provider
   no -> fallback policy
```

fallback 예:

```text
cuda requested but unavailable
-> cpu fallback
-> response metadata에 fallbackProvider 기록
```

## 성능 비교표

| provider | 비교 지표 |
|---|---|
| CPU | baseline p50/p95, memory |
| CUDA | inference_ms 감소 여부, total_ms 변화 |
| Triton | network latency, queue time, throughput |

## 실무 판단

GPU 도입 판단은 다음 순서로 한다.

1. CPU baseline 측정
2. CUDA provider 측정
3. total_ms 기준 개선 여부 확인
4. p95와 cold start 확인
5. 동시 요청에서 throughput 확인
6. 운영 복잡도와 이득 비교

## 면접용 답변

> GPU나 Triton을 붙이는 것 자체가 목표는 아니라고 봅니다. 먼저 ONNX Runtime CPU로 baseline을 만들고, CUDA provider에서 inference_ms와 total_ms가 실제로 줄어드는지 p50/p95로 비교합니다. Triton은 여러 모델과 동시 요청, GPU worker 운영이 필요할 때 provider 뒤에 추가하는 구조로 설계했습니다.

