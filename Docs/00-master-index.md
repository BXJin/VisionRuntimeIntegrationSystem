# Vision Runtime Integration System master index

이 폴더는 사용자가 올린 두 종류의 공고를 함께 겨냥하는 장기 실무형 프로젝트를 정리한다.

- 공고 A: 특정 언어보다 문제 해결, 레거시 이해, 장비 제어, API 연동, 비동기 상태 관리, 운영 안정화를 강조하는 시스템 통합 직무
- 공고 B: Google Pixel Camera류의 camera system software, C++, image processing, performance optimization, system integration을 강조하는 직무

이 프로젝트의 목표는 단순 데모가 아니라 **C++ runtime/client, Python inference gateway, camera/device input, image processing, inference provider, metrics/ops를 분리한 실무형 통합 시스템**을 설계하고 단계적으로 구현하는 것이다.

## 한 줄 정의

카메라/장비 입력을 C++ runtime 계층에서 안정적으로 수집하고, Python inference gateway에서 OpenCV/ONNX/Triton 추론을 수행한 뒤, 결과를 typed contract와 callback/event로 다시 클라이언트에 전달하는 Vision Runtime Integration System.

## 핵심 아키텍처

```text
Camera / Device / File Input
-> C++ Runtime Integration Client
   -> capture / encode / request id / async HTTP or WebSocket
   -> timeout / cancel / stale response / callback
-> Python Inference Gateway
   -> FastAPI endpoint
   -> OpenCV preprocessing
   -> ONNX Runtime CPU/CUDA provider
   -> future Triton provider
   -> result contract validation
   -> metrics CSV
-> C++ Runtime Result Layer
   -> typed result parsing
   -> state transition
   -> UI / log / downstream action
```

## 문서 읽는 순서

1. `00-master-index.md`
   - 전체 목적, 문서 구조, 프로젝트 판단 기준.
2. `01-position-requirement-map.md`
   - 올려준 공고 요구사항을 프로젝트 기능으로 매핑.
3. `02-product-scope-and-non-goals.md`
   - 무엇을 만들고 무엇을 만들지 않을지 정의.
4. `03-system-architecture.md`
   - 전체 컴포넌트, 데이터 흐름, 배포 형태.
5. `04-cpp-runtime-client-design.md`
   - C++ runtime/client 계층 설계.
6. `05-python-inference-gateway-design.md`
   - FastAPI, OpenCV, ONNX Runtime provider 설계.
7. `06-camera-input-and-device-integration.md`
   - 파일, 웹 카메라, USB camera, 장비 SDK 입력 전략.
8. `07-image-processing-pipeline.md`
   - decode, resize, color conversion, tensor 변환, 품질 정책.
9. `08-inference-provider-and-gpu-scaling.md`
   - CPU, CUDA, TensorRT, Triton 확장 전략.
10. `09-state-async-error-handling.md`
    - request id, timeout, stale response, retry, fallback.
11. `10-performance-metrics-and-benchmark-plan.md`
    - 적용 전/후, p50/p95, client/server metric join.
12. `11-roadmap-and-portfolio-story.md`
    - 단계별 구현 순서, 면접/포트폴리오 스토리.

## PM 판단 기준

- 이 프로젝트는 "카메라 AI 데모"가 아니라 "카메라/장비 입력을 AI 추론 서비스로 안정적으로 연결하는 시스템 통합 프로젝트"다.
- C++은 모델 추론 자체보다 runtime, SDK, client integration, callback, state, memory, timeout을 맡는다.
- Python은 inference gateway, model provider, OpenCV preprocessing, metrics, provider switching을 맡는다.
- Triton은 처음부터 넣지 않는다. ONNX Runtime으로 contract와 metrics를 고정한 뒤 확장한다.
- native camera SDK도 처음부터 넣지 않는다. file input -> mobile browser still capture -> USB camera -> SDK 순서로 확장한다.

## 개발 판단 기준

금지:

- C++/OpenCV/ONNX/Triton을 한 번에 붙이는 빅뱅 구현
- 측정 없는 "GPU가 빠르다" 주장
- Python server latency만 보고 end-to-end latency라고 말하기
- 모바일 브라우저 카메라를 native camera SDK 경험이라고 과장하기
- 이 프로젝트만으로 Android HAL, ISP, Pixel camera stack 경험이라고 말하기

우선:

- 작은 입력부터 end-to-end로 연결
- client/server 지표를 request id로 결합
- 실패 유형을 명확히 분리
- p50뿐 아니라 p95와 cold start를 확인
- 구현한 것과 설계한 것을 면접에서 구분

