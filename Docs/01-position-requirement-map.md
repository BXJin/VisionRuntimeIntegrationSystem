# Position requirement map

## 목적

사용자가 올린 두 공고 이미지를 하나의 장기 프로젝트로 흡수하기 위해, 요구사항을 프로젝트 기능과 산출물로 매핑한다.

## 공고 A 요약

핵심 성격:

- 특정 언어보다 문제 해결과 구조 개선
- 레거시 코드 이해 후 안정적 개선
- C/C++/C#/Python/Java 중 하나 이상으로 소프트웨어 설계/구현
- 데스크톱 앱, 장비 제어, 자동화 시스템, 응용 소프트웨어
- 비동기 처리, 상태 관리, 예외 처리
- API 연동, 데이터 처리, 모듈 분리
- 장비 SDK, 카메라 SDK, 외부 라이브러리 연동
- Serial, Socket, TCP/IP, Modbus 등 장비/센서 통신
- Python 기반 서비스, AI 추론 모듈, 분석 파이프라인
- React 또는 웹 프론트엔드 이해

## 공고 B 요약

핵심 성격:

- Pixel camera system software stack
- mobile camera user experience
- C++ programming
- camera system software
- performance optimization
- operating systems
- image processing
- system integration solutions
- cross-functional collaboration

## 통합 프로젝트로 번역

| 공고 요구 | 프로젝트 기능 | 산출물 |
|---|---|---|
| 문제 해결과 구조 개선 | C++ runtime, Python gateway, provider, metrics 분리 | `03-system-architecture.md` |
| 레거시 코드 개선 | 기존 PromptMotionLab provider/metrics 구조를 재사용 가능한 형태로 재해석 | reuse notes, migration plan |
| C++ 경험 | C++ Runtime Integration Client | `04-cpp-runtime-client-design.md` |
| Python 기반 서비스 | FastAPI Inference Gateway | `05-python-inference-gateway-design.md` |
| API 연동 | C++ client -> Python gateway HTTP/WebSocket | endpoint contract |
| 비동기 상태 관리 | request id, job id, stale response, timeout | `09-state-async-error-handling.md` |
| 장비/카메라 SDK | file/webcam/mobile/USB camera/SDK input strategy | `06-camera-input-and-device-integration.md` |
| 이미지 처리 | OpenCV preprocessing pipeline | `07-image-processing-pipeline.md` |
| AI 추론 모듈 | ONNX Runtime CPU/CUDA, future Triton | `08-inference-provider-and-gpu-scaling.md` |
| 성능 최적화 | p50/p95, cold/warm, client/server metric join | `10-performance-metrics-and-benchmark-plan.md` |
| 운영 안정화 | health check, error taxonomy, fallback, release gates | `11-roadmap-and-portfolio-story.md` |

## 면접에서 말할 포지셔닝

> 이 프로젝트는 단순 이미지 분류 데모가 아니라, 카메라 또는 장비 입력을 C++ runtime 계층에서 안정적으로 받아 Python inference gateway로 전달하고, OpenCV/ONNX/Triton 계층의 결과를 다시 typed contract로 받아 처리하는 시스템 통합 프로젝트입니다. 그래서 장비/API 연동, C++ runtime 상태 관리, Python 추론 서비스, image processing, 성능 계측을 한 흐름에서 보여줄 수 있습니다.

## 과장하면 안 되는 부분

| 말하면 안 되는 주장 | 이유 | 안전한 표현 |
|---|---|---|
| Pixel camera stack을 구현했다 | Android camera HAL/ISP가 아님 | camera input to inference pipeline PoC |
| Camera SDK 실무 경험이 있다 | 실제 SDK 연동 전이면 과장 | Camera SDK 연동을 고려한 input abstraction 설계 |
| Triton 운영 경험이 있다 | 실제 배포 전이면 과장 | Triton provider 확장 설계 |
| C++ image processing engine을 만들었다 | 초기 C++은 runtime/client 중심 | C++ runtime integration client 구현 |
| GPU 최적화를 했다 | 수치 비교 전이면 위험 | CPU/CUDA 비교 계획 또는 측정 결과 기준 |

## 이 프로젝트가 보완하는 약점

- 순수 C++ 상용 경력 부족
- OpenCV/영상 처리 실전 경험 부족
- 직접 운영하는 추론 서버 경험 부족
- CUDA/Triton 운영 경험 부족
- 장비/카메라 SDK 연동 경험 부족

다만 이 약점을 한 번에 해결했다고 주장하지 않는다. 단계별로 다음처럼 말한다.

```text
Phase 1: Python inference gateway로 추론 서비스 구조와 metrics 기준 확립
Phase 2: C++ runtime client로 API 연동, timeout, callback, stale response 검증
Phase 3: camera input source 확장
Phase 4: CPU/CUDA/Triton provider 비교
Phase 5: 운영/릴리즈 기준 정리
```

