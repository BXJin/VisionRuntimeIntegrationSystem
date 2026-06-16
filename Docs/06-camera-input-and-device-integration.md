# Camera input and device integration

## 목적

카메라/장비 입력은 범위가 쉽게 커지는 영역이다. 이 문서는 input source를 단계별로 확장하는 전략을 정리한다.

## input source 단계

| 단계 | 입력 | 난이도 | 목적 |
|---|---|---:|---|
| 1 | image file | 낮음 | preprocessing/inference baseline |
| 2 | mobile browser still capture | 낮음~중간 | 실제 카메라 입력에 가까운 단발 흐름 |
| 3 | USB webcam still frame | 중간 | PC camera capture와 frame handling |
| 4 | USB webcam streaming | 높음 | frame drop, stale frame, FPS 제어 |
| 5 | Camera SDK / device SDK | 높음 | 장비/SDK 연동 경험 |
| 6 | native Android CameraX | 높음 | mobile native camera layer |

## 왜 file input부터 시작하는가

모델과 전처리 기준이 고정되지 않은 상태에서 camera SDK를 붙이면 디버깅 지점이 너무 많아진다.

먼저 file input으로 다음을 고정한다.

- 이미지 decode 방식
- target size
- color conversion
- normalization
- model input layout
- response contract
- metric schema

## mobile browser still capture

구조:

```text
phone browser
-> getUserMedia
-> capture canvas still image
-> JPEG encode
-> POST /api/vision/classify
-> result display
```

장점:

- native app 없이 휴대폰 카메라 입력을 실험할 수 있다.
- Wi-Fi upload와 image size 영향을 볼 수 있다.
- 실시간 streaming보다 범위가 작다.

단점:

- native camera SDK 경험은 아니다.
- camera controls, exposure, focus, frame pipeline 제어가 제한적이다.

## USB webcam still frame

구조:

```text
C++ client or Python script
-> webcam frame capture
-> select latest frame
-> encode JPEG
-> gateway upload
```

학습 포인트:

- frame capture loop
- latest frame selection
- capture timestamp
- encode cost
- stale frame drop

## device SDK 확장

장비 SDK가 들어오면 input adapter가 필요하다.

```text
IFrameSource
  - FileFrameSource
  - MobileUploadFrameSource
  - UsbCameraFrameSource
  - VendorCameraSdkFrameSource
```

각 source는 공통 frame contract로 변환한다.

```json
{
  "source": "vendor_camera_sdk",
  "frameId": "frame_001",
  "timestamp": "2026-06-16T10:00:00Z",
  "width": 1920,
  "height": 1080,
  "format": "BGR8|RGB8|JPEG|NV12",
  "bytes": "..."
}
```

## 장비/센서 통신 확장

공고 A의 Serial, Socket, TCP/IP, Modbus 요구는 다음 단계에서 연결한다.

예시:

```text
device sensor state
-> serial/tcp adapter
-> C++ runtime state
-> attach metadata to vision request
-> inference result + device state
```

처음부터 구현하지 않는 이유:

- 장비가 없으면 mock이 많아진다.
- vision pipeline baseline이 먼저다.
- 통신 프로토콜은 별도 PoC로 분리하는 것이 낫다.

## 실무 리스크

| 리스크 | 설명 | 대응 |
|---|---|---|
| frame flood | 카메라가 너무 많은 frame을 보냄 | latest-only 또는 sampling |
| stale frame | 오래된 frame 결과가 뒤늦게 도착 | frame id/request id 검증 |
| encode cost | JPEG encoding이 예상보다 오래 걸림 | encode_ms 측정 |
| network jitter | 모바일 Wi-Fi 지연 | upload_ms/RTT 분리 |
| device disconnect | USB/SDK 연결 끊김 | reconnect state |
| format mismatch | RGB/BGR/NV12 혼동 | format metadata 명시 |

## 면접용 답변

> 카메라 입력은 바로 native SDK나 실시간 streaming으로 가지 않고 단계적으로 확장하는 것이 안전하다고 봤습니다. 먼저 image file로 전처리와 모델 입력 계약을 고정하고, 다음에 모바일 브라우저 still capture와 USB webcam으로 실제 카메라 입력에 가까운 흐름을 검증합니다. 장비 SDK는 input adapter만 교체하도록 `FrameSource` 개념으로 분리해두는 방향입니다.

