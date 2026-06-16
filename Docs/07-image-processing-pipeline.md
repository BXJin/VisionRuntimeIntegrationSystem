# Image processing pipeline

## 목적

이미지 처리 파이프라인은 모델 정확도와 latency 모두에 영향을 준다. 이 문서는 OpenCV preprocessing 흐름과 측정 기준을 정리한다.

## 기본 흐름

```text
image bytes
-> decode
-> validate
-> resize / crop
-> color conversion
-> normalize
-> layout transform
-> tensor
```

## 단계별 설명

### 1. decode

```text
JPEG/PNG bytes -> OpenCV image
```

측정:

- `decode_ms`
- input bytes
- original width/height

실무 포인트:

큰 이미지일수록 모델 추론보다 decode가 병목이 될 수 있다.

### 2. validate

확인:

- 이미지 decode 성공 여부
- width/height 유효성
- channel 수
- 최대 파일 크기
- 지원 포맷

실패 시:

```text
400 invalid_image
413 too_large
415 unsupported_format
```

### 3. resize / crop

모델 입력 크기 예:

```text
224x224
```

비교 후보:

- direct resize
- center crop
- letterbox

처음은 direct resize로 시작한다. 모델 정확도 실험이 목적이 아니라 integration과 latency 측정이 목적이기 때문이다.

### 4. color conversion

OpenCV는 기본적으로 BGR을 사용한다. 대부분 ImageNet ONNX 모델은 RGB 입력을 기대한다.

```text
BGR -> RGB
```

이 단계를 빼면 모델이 실행은 되지만 결과가 이상해질 수 있다.

### 5. normalize

예:

```text
pixel / 255.0
mean/std normalization
```

모델마다 mean/std가 다를 수 있으므로 model config로 분리한다.

### 6. layout transform

OpenCV/NumPy 이미지:

```text
HWC
```

ONNX 모델 입력:

```text
NCHW
```

변환:

```text
height, width, channel
-> batch, channel, height, width
```

## model config

```json
{
  "modelName": "mobilenetv3",
  "inputWidth": 224,
  "inputHeight": 224,
  "colorSpace": "RGB",
  "layout": "NCHW",
  "normalize": {
    "scale": 0.0039215686,
    "mean": [0.485, 0.456, 0.406],
    "std": [0.229, 0.224, 0.225]
  }
}
```

## 성능 측정

CSV:

```text
decode_ms
resize_ms
color_convert_ms
normalize_ms
layout_ms
preprocess_ms
```

초기에는 `preprocess_ms` 하나로 시작하고, 병목이 보이면 세부 항목으로 나눈다.

## 적용 전/후

적용 전:

```text
이미지를 모델 입력으로 바꾸는 과정이 코드에 흩어짐
성능 병목이 decode인지 resize인지 추론인지 알 수 없음
```

적용 후:

```text
OpenCV preprocessing module로 분리
model config 기반 변환
decode/preprocess/inference latency 분리
```

## 품질 검증

간단한 검증:

- 같은 이미지 입력 시 같은 top-1 결과
- BGR/RGB 변환 제거 시 결과가 달라지는지 확인
- 720p/1080p/4K에서 preprocess_ms 비교
- 잘못된 이미지 입력 시 500이 아니라 400

## 면접용 답변

> OpenCV는 단순히 이미지를 읽기 위해 쓰는 것이 아니라, 모델이 기대하는 입력 tensor로 변환하는 역할을 합니다. decode, resize, BGR-RGB 변환, normalize, HWC-NCHW 변환을 명시적으로 나누고, 각 구간의 latency를 기록해 실제 병목이 전처리인지 추론인지 구분할 수 있게 설계했습니다.

