# C++ runtime client design

## 목적

C++을 단순히 "API 호출 언어"가 아니라 runtime/system integration 계층으로 사용한다. 이 문서는 C++ client가 맡을 책임과 구현 포인트를 정의한다.

## C++이 맡는 역할

```text
Input source
-> frame/image acquisition
-> request object 생성
-> async transport
-> timeout/cancel/stale guard
-> JSON result parsing
-> typed callback/event
-> client metrics
```

## C++이 맡지 않는 역할

- 모델 학습
- ONNX provider routing 초기 단계
- OpenCV preprocessing 초기 단계
- Triton server 운영
- 대시보드 UI

이 역할은 Python gateway가 맡는다. C++은 실시간 runtime과 client integration 안정성에 집중한다.

## 주요 클래스 후보

```text
VisionRuntimeClient
  - public API
  - Start(), Stop(), SubmitImageAsync(), Cancel()

VisionRequest
  - requestId
  - source
  - imagePath or bytes
  - timeoutMs

VisionResponse
  - requestId
  - predictions
  - serverLatency
  - error

HttpTransport
  - multipart upload
  - async callback

VisionStateMachine
  - Idle
  - Capturing
  - Uploading
  - WaitingInference
  - Completed
  - Failed
  - Cancelled

ClientMetricsLogger
  - upload_ms
  - round_trip_ms
  - json_parse_ms
  - total_ms
```

## 상태 전이

```text
Idle
-> Capturing
-> Uploading
-> WaitingInference
-> Completed

WaitingInference
-> Timeout
-> Failed

Uploading or WaitingInference
-> Cancelled
```

## request id와 stale response

문제:

```text
Request A 전송
Request B 전송
B가 먼저 도착
A가 늦게 도착
```

대응:

```text
activeRequestId == response.requestId 인 경우만 적용
다르면 stale response로 기록하고 무시
```

면접 표현:

> 객체가 살아 있는지 확인하는 것과 현재 요청의 응답인지 확인하는 것은 다른 문제입니다. C++ client에서는 weak reference나 수명 체크뿐 아니라 request id를 비교해 오래된 응답이 현재 상태를 덮어쓰지 못하게 설계합니다.

## 메모리와 소유권

| 대상 | 권장 소유권 |
|---|---|
| VisionRuntimeClient 내부 transport | `std::unique_ptr` 또는 UE `TUniquePtr` |
| callback 공유 상태 | `std::shared_ptr` 또는 UE `TSharedPtr` |
| async callback capture | `std::weak_ptr` 또는 UE `TWeakPtr` |
| 큰 image byte buffer | move semantics |
| 결과 callback | function/lambda, lifecycle guard |

## transport 선택

### 초기

```text
HTTP multipart upload
```

장점:

- 구현이 단순하다.
- 파일/이미지 단발 요청에 적합하다.
- FastAPI와 맞다.

### 확장

```text
WebSocket streaming
```

사용 시점:

- 연속 frame
- 실시간 camera preview
- partial result
- server event

## client metrics

CSV 컬럼:

```text
timestamp
request_id
source
image_bytes
upload_ms
round_trip_ms
json_parse_ms
total_client_ms
server_total_ms
status
error_type
stale_response
timeout
```

## 첫 구현 범위

1. C++ console client
2. 이미지 파일 경로 입력
3. multipart upload
4. JSON response parsing
5. request id 검증
6. timeout
7. CSV logging

## 나중 구현 범위

- USB camera capture
- WebSocket streaming
- SDK-style API wrapper
- Unreal plugin wrapper
- Windows desktop tray/debug UI

## 실무 연결

이 C++ 계층은 다음 직무와 연결된다.

- 장비 SDK wrapper
- camera SDK input adapter
- client runtime
- customer SDK
- media streaming client
- native module
- desktop application backend

## 면접용 답변

> C++은 모델 추론 자체보다 runtime integration 쪽에 배치했습니다. 이미지 입력을 받아 비동기 요청을 보내고, request id, timeout, cancel, stale response, JSON parsing, callback을 관리합니다. 실제 장비 SDK나 camera system software에서도 모델 서버가 빠른 것과 별개로 client runtime이 상태와 수명을 잘 관리해야 하기 때문에, 이 계층을 C++로 설계했습니다.

