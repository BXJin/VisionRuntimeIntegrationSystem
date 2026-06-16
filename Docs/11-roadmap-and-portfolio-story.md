# Roadmap and portfolio story

## 목적

Vision Runtime Integration System을 장기 프로젝트로 단계별 구현하기 위한 로드맵과, 면접/포트폴리오에서 설명할 스토리를 정리한다.

## Phase 0 - 설계와 기준 확정

목표:

- 공고 요구사항 매핑
- 전체 아키텍처 문서화
- 성공 기준과 제외 범위 정의

산출물:

- `00~11` 문서 세트
- component boundary
- benchmark plan

완료 기준:

- C++/Python/Camera/Inference/Metrics 계층이 분리되어 설명 가능

## Phase 1 - Python inference gateway

목표:

- FastAPI endpoint
- OpenCV preprocessing
- ONNX Runtime CPU provider
- server metrics CSV

구현:

```text
POST /api/vision/classify
GET /api/vision/health
```

측정:

- decode_ms
- preprocess_ms
- inference_ms
- total_server_ms

완료 기준:

- 이미지 100회 요청 p50/p95 산출
- invalid image 400 처리
- model session 재사용

## Phase 2 - C++ runtime client

목표:

- C++ console client
- async HTTP/multipart upload
- request id
- timeout
- JSON parsing
- client metrics CSV

완료 기준:

- C++ client가 Python gateway 호출
- server/client CSV request id join 가능
- stale response guard 설명 가능

## Phase 3 - camera input 확장

목표:

- mobile browser still capture
- USB webcam still frame
- input source abstraction

완료 기준:

- file input과 camera input이 같은 server contract 사용
- capture/encode/upload latency 기록

## Phase 4 - provider 비교

목표:

- ONNX Runtime CUDA provider
- CPU vs CUDA 비교
- MobileNet vs ResNet 비교

완료 기준:

- p50/p95 표 작성
- GPU가 실제로 유리한 조건과 불리한 조건 설명 가능

## Phase 5 - Triton 확장 설계 또는 PoC

목표:

- Triton provider skeleton
- HTTP/gRPC 호출 방식 검토
- queue time, network latency 측정 계획

완료 기준:

- Triton을 붙일 위치와 붙이지 말아야 할 이유를 모두 설명 가능

## Phase 6 - 운영 안정화

목표:

- health check
- warm-up
- provider fallback
- error taxonomy
- benchmark report 자동 생성

완료 기준:

- release gate 문서화
- 장애 유형별 대응 정리

## 포트폴리오 스토리

### 30초 버전

> Vision Runtime Integration System은 카메라/이미지 입력을 C++ runtime client에서 받아 Python inference gateway로 전달하고, OpenCV 전처리와 ONNX Runtime 추론 결과를 다시 typed contract로 받는 시스템 통합 프로젝트입니다. 핵심은 이미지 분류 자체가 아니라 C++ client의 request id, timeout, stale response 처리와 Python server의 decode/preprocess/inference latency를 request id 기준으로 합쳐 end-to-end 병목을 찾는 구조입니다.

### 1분 버전

> 기존 PromptMotionLab에서는 OpenAI/Azure 같은 외부 AI provider를 FastAPI로 연결하고 Unreal C++ client에서 음성/표정 상태를 관리했습니다. 하지만 OpenCV, 로컬 추론, 카메라/장비 입력, GPU provider 경험은 부족했습니다. 그래서 새 프로젝트에서는 카메라 입력을 C++ runtime 계층에서 다루고, Python inference gateway에서 OpenCV 전처리와 ONNX Runtime 추론을 수행하도록 나눴습니다. 이 구조는 장비 SDK나 camera system software 직무에서 중요한 input source abstraction, async request, timeout, typed result contract, p50/p95 성능 계측을 작게 검증할 수 있습니다.

## 공고별 어필 포인트

### 장비/시스템 통합 직무

- C++/Python 모듈 경계 설계
- API 연동과 데이터 contract
- 비동기 상태와 예외 처리
- 장비 SDK로 확장 가능한 input adapter
- 운영 안정화와 성능 지표

### Camera system software 직무

- camera input -> image processing -> inference pipeline
- C++ runtime client
- image preprocessing
- performance p50/p95
- system integration solution

### AI Integration 직무

- Python inference gateway
- ONNX Runtime provider
- future Triton provider
- model output -> service contract
- fallback and health check

## 냉정한 리스크

| 리스크 | 설명 | 대응 |
|---|---|---|
| 범위 과대 | camera, C++, Python, GPU를 동시에 하면 느려짐 | Phase 단위로 구현 |
| C++ 빌드 지연 | OpenCV/ONNX C++ 링크 문제 | C++은 client runtime부터 |
| GPU 환경 문제 | CUDA/driver 버전 문제 | CPU baseline 먼저 |
| 과장 위험 | Pixel camera stack으로 보이면 안 됨 | 정확히 camera input inference integration이라고 표현 |
| 측정 부실 | 수치 없으면 설득력 없음 | CSV와 benchmark report 필수 |

## 최종 판단

이 프로젝트는 단기 면접용 데모보다 장기 포트폴리오로 더 가치가 있다. 특히 C++을 모델 추론 엔진이 아니라 runtime integration 계층에 배치하면, 현재 PromptMotionLab의 비동기/상태/latency 경험과 자연스럽게 이어진다.

가장 먼저 구현할 것은 다음이다.

```text
Python inference gateway + C++ runtime client + request id 기반 metrics join
```

이 한 줄이 완성되면 이후 camera input, CUDA, Triton은 단계적으로 붙일 수 있다.

