# Python inference gateway design

## 목적

Python gateway는 모델 추론과 전처리, provider 교체, 서버 metric을 담당한다. C++ runtime client가 직접 모델과 OpenCV를 모두 들고 있지 않도록 경계를 만든다.

## 역할

```text
FastAPI request
-> validation
-> OpenCV preprocessing
-> inference provider
-> postprocess
-> response contract
-> metrics CSV
```

## endpoint 후보

### `POST /api/vision/classify`

이미지 한 장을 받아 top-k classification 결과를 반환한다.

### `GET /api/vision/health`

모델 로드 상태, provider 상태, GPU 사용 가능 여부를 반환한다.

### `POST /api/vision/warmup`

모델 warm-up 요청. 첫 요청 latency를 줄이기 위해 사용한다.

### `GET /api/vision/metrics/summary`

개발용. CSV를 요약해 p50/p95를 반환한다.

## service 구조

```text
app/
  api/
    vision_routes.py
  services/
    vision_inference_service.py
    vision_metrics_service.py
  providers/
    inference/
      base.py
      mock_provider.py
      onnx_runtime_provider.py
      triton_provider.py
  preprocessing/
    opencv_preprocessor.py
  contracts/
    vision_request.py
    vision_response.py
```

## provider interface

```python
class VisionInferenceProvider:
    async def predict(self, tensor: np.ndarray) -> VisionPredictionResult:
        ...
```

초기 provider:

- `MockVisionProvider`
- `OnnxRuntimeCpuProvider`
- `OnnxRuntimeCudaProvider`

후속 provider:

- `TritonHttpProvider`
- `TritonGrpcProvider`

## 왜 provider를 나누는가

- CPU/CUDA/Triton 교체를 endpoint와 분리한다.
- benchmark에서 provider만 바꿔 비교할 수 있다.
- provider 실패 시 fallback 정책을 명확히 둔다.
- 테스트에서 mock provider로 외부 의존성을 제거한다.

## preprocessing output

```json
{
  "originalWidth": 1920,
  "originalHeight": 1080,
  "modelWidth": 224,
  "modelHeight": 224,
  "colorSpace": "RGB",
  "layout": "NCHW",
  "dtype": "float32"
}
```

## response contract

```json
{
  "requestId": "vision_001",
  "status": "ok",
  "predictions": [
    { "label": "camera", "score": 0.91 }
  ],
  "serverLatencyMs": {
    "decode": 3.2,
    "preprocess": 4.1,
    "inference": 18.6,
    "postprocess": 0.8,
    "total": 31.4
  }
}
```

## 오류 응답

| errorType | HTTP | 의미 |
|---|---:|---|
| invalid_image | 400 | OpenCV decode 실패 |
| too_large | 413 | 허용 크기 초과 |
| unsupported_format | 415 | 형식 미지원 |
| model_unavailable | 503 | 모델 로드 실패 |
| inference_timeout | 504 | 추론 timeout |
| provider_error | 502 | provider 내부 오류 |

## metric CSV

```text
timestamp
request_id
route
model_name
provider
input_bytes
original_width
original_height
decode_ms
preprocess_ms
inference_ms
postprocess_ms
total_server_ms
success
error_type
top1_label
top1_score
```

## 실무 판단

Python gateway는 빠르게 모델을 붙이고 실험하기 좋다. 하지만 CPU 작업이 많으므로 `async def`만으로 성능 문제가 해결되지 않는다.

주의:

- ONNX inference는 CPU/GPU 작업이므로 event loop blocking을 확인해야 한다.
- 큰 이미지 파일은 request size limit을 둔다.
- 모델 session은 요청마다 만들지 않는다.
- warm-up과 health check를 분리한다.
- p95가 나빠지면 평균이 좋아도 실시간 서비스에는 위험하다.

## 면접용 답변

> Python gateway는 모델 추론과 전처리를 담당하도록 분리했습니다. FastAPI endpoint는 이미지 입력을 검증하고, OpenCV preprocessing을 거쳐 ONNX Runtime provider를 호출합니다. provider interface를 두어서 CPU, CUDA, Triton을 같은 계약으로 비교할 수 있게 했고, decode/preprocess/inference/postprocess 시간을 CSV로 기록해 병목을 수치로 확인할 수 있게 설계했습니다.

