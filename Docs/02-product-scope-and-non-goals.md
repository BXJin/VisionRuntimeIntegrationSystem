# Product scope and non-goals

## 목적

장기 프로젝트라도 처음부터 범위를 무제한으로 잡으면 실패한다. 이 문서는 Vision Runtime Integration System에서 만들 것과 만들지 않을 것을 분리한다.

## 제품 정의

카메라/이미지 입력을 받아 C++ runtime 계층에서 요청 상태를 관리하고, Python inference gateway에서 이미지 전처리와 모델 추론을 수행한 뒤, 결과를 다시 C++ client가 안전하게 수신하는 실무형 통합 시스템.

## 핵심 사용자

이 프로젝트의 "사용자"는 일반 소비자가 아니라 면접관 또는 기술 검토자다.

그들이 보고 싶은 것:

- C++을 문법이 아니라 runtime/system integration 문제에 적용했는가
- Python inference service를 단순 API 호출 이상으로 구조화했는가
- 이미지 처리와 모델 추론을 구간별로 측정했는가
- 오류, timeout, stale response, fallback을 고려했는가
- 장비/카메라/SDK 업무로 확장 가능한 구조인가

## 핵심 시나리오

### Scenario 1. 파일 기반 추론

```text
C++ 또는 Python client가 이미지 파일 업로드
-> Python gateway가 OpenCV 전처리
-> ONNX Runtime 추론
-> Top-k result JSON 반환
-> metrics CSV 기록
```

### Scenario 2. C++ runtime 연동

```text
C++ client가 request id 생성
-> 비동기 HTTP request 전송
-> timeout timer 시작
-> response 수신
-> request id 검증
-> JSON result를 typed struct로 변환
-> callback으로 상위 계층에 전달
```

### Scenario 3. 카메라 입력 확장

```text
Mobile browser still capture 또는 USB webcam
-> frame/image 생성
-> gateway 업로드
-> inference result
-> end-to-end latency 측정
```

### Scenario 4. GPU/Triton 확장

```text
ONNX Runtime CPU baseline
-> ONNX Runtime CUDA 비교
-> future Triton provider
-> p50/p95, cold start, throughput 비교
```

## 포함 범위

| 영역 | 포함 |
|---|---|
| C++ | runtime client, async request, timeout, JSON parsing, metric logging |
| Python | FastAPI gateway, OpenCV preprocessing, ONNX Runtime provider |
| Camera | file input, mobile browser still image, USB webcam extension |
| Image processing | decode, resize, color conversion, normalization, tensor transform |
| Inference | MobileNet/ResNet ONNX, CPU/CUDA provider |
| Metrics | server CSV, client CSV, request id join, p50/p95 |
| Ops | health check, invalid input, timeout, fallback policy |

## 제외 범위

| 제외 | 이유 |
|---|---|
| Android camera HAL | 범위가 OS/driver 계층으로 커짐 |
| ISP pipeline | 전문 camera firmware/image tuning 영역 |
| native Android app | CameraX 앱까지 만들면 핵심이 흐려짐 |
| 실시간 video streaming | WebRTC/GStreamer까지 커짐 |
| Triton production 운영 | 초기에는 provider contract와 baseline이 먼저 |
| TensorRT 변환 자동화 | ONNX Runtime baseline 이후 단계 |
| 모델 학습 | 직무 보강 목적은 serving/integration |
| 상용 UI | 핵심은 runtime, inference, metrics |

## 성공 기준

### 기술 성공 기준

- C++ client와 Python gateway가 request id 기준으로 연결된다.
- 서버는 decode/preprocess/inference/postprocess/total latency를 기록한다.
- 클라이언트는 upload/round-trip/json-parse/total latency를 기록한다.
- 잘못된 이미지, timeout, stale response가 구분된다.
- 같은 모델을 CPU/CUDA provider로 교체할 수 있는 구조다.
- camera input source를 file에서 webcam/SDK로 바꿀 수 있는 abstraction이 있다.

### 포트폴리오 성공 기준

- "C++을 어디에 썼는가"를 runtime problem으로 설명할 수 있다.
- "OpenCV를 왜 썼는가"를 preprocessing problem으로 설명할 수 있다.
- "GPU/Triton은 언제 의미가 있는가"를 수치 기준으로 설명할 수 있다.
- "실무에 바로 들어갈 수 있는가"에 대해 API contract, metrics, failure handling으로 답할 수 있다.

## 냉정한 판단

이 프로젝트는 잘 만들면 여러 공고에 걸쳐 좋은 포트폴리오가 된다. 하지만 처음부터 너무 많은 것을 구현하면 완성도가 떨어진다.

따라서 첫 구현은 다음 하나를 증명해야 한다.

> C++ runtime client와 Python inference gateway를 나누고, 이미지 추론 결과와 latency를 request id 기준으로 end-to-end 추적할 수 있다.

