class MovingAverage {
  var samples: Array<Double>
  var sampleCount = 0
  var period = 5
  
  init(period: Int = 5) {
    self.period = period
    self.samples = Array<Double>()
  }
  
  var average: Double {
    let sum: Double = self.samples.reduce(0, +)
    
    if period > self.samples.count {
      return sum / Double(self.samples.count)
    } else {
      return sum / Double(self.period)
    }
  }
  
  func addSample(value: Double) -> Double {

    let pos = self.sampleCount % self.period
    self.sampleCount += 1
    
    if pos >= samples.count {
      self.samples.append(value)
    } else {
      self.samples[pos] = value
    }
    
    return average
  }
}
