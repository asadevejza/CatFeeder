using Image = SixLabors.ImageSharp.Image;
using SixLabors.ImageSharp;
using SixLabors.ImageSharp.PixelFormats;
using SixLabors.ImageSharp.Processing;
using Microsoft.ML.OnnxRuntime;
using Microsoft.ML.OnnxRuntime.Tensors;

namespace CatFeeder.Servis.Servisi
{
    public record CatDetectionResult(bool CatDetected, double Confidence, string TopLabel);

    // Učitava pretrenirani MobileNetV2 (ImageNet, 1000 klasa) i provjerava
    // da li slika sadrži mačku (klase 281-285: tabby, tiger cat, Persian,
    // Siamese, Egyptian cat).
    public class CatDetectionServis : IDisposable
    {
        private readonly InferenceSession _session;
        private static readonly int[] CatClassIndices = { 281, 282, 283, 284, 285 };
        private static readonly float[] MeanRgb = { 0.485f, 0.456f, 0.406f };
        private static readonly float[] StdRgb = { 0.229f, 0.224f, 0.225f };

        public CatDetectionServis(string modelPath)
        {
            _session = new InferenceSession(modelPath);
        }

        public CatDetectionResult Detect(byte[] imageBytes)
        {
            using var image = Image.Load<Rgb24>(imageBytes);
            image.Mutate(x => x.Resize(new ResizeOptions
            {
                Size = new Size(224, 224),
                Mode = ResizeMode.Crop
            }));

            var input = new DenseTensor<float>(new[] { 1, 3, 224, 224 });
            for (int y = 0; y < 224; y++)
            {
                for (int x = 0; x < 224; x++)
                {
                    var pixel = image[x, y];
                    input[0, 0, y, x] = (pixel.R / 255f - MeanRgb[0]) / StdRgb[0];
                    input[0, 1, y, x] = (pixel.G / 255f - MeanRgb[1]) / StdRgb[1];
                    input[0, 2, y, x] = (pixel.B / 255f - MeanRgb[2]) / StdRgb[2];
                }
            }

            var inputName = _session.InputMetadata.Keys.First();
            var inputs = new List<NamedOnnxValue> { NamedOnnxValue.CreateFromTensor(inputName, input) };

            using var results = _session.Run(inputs);
            var output = results.First().AsEnumerable<float>().ToArray();
            var probabilities = Softmax(output);

            var catScore = CatClassIndices.Sum(i => probabilities[i]);
            var topIndex = Array.IndexOf(probabilities, probabilities.Max());

            return new CatDetectionResult(
                CatDetected: catScore > 0.3,
                Confidence: catScore,
                TopLabel: CatClassIndices.Contains(topIndex) ? "cat" : $"class_{topIndex}"
            );
        }

        private static float[] Softmax(float[] logits)
        {
            var max = logits.Max();
            var exps = logits.Select(v => Math.Exp(v - max)).ToArray();
            var sum = exps.Sum();
            return exps.Select(v => (float)(v / sum)).ToArray();
        }

        public void Dispose() => _session.Dispose();
    }
}