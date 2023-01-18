It's a Segway or something. More details to come.

The segway utilizes a gyroscope and accelerometer for physical readings about the position and balance of the segway and rider. Our hardware uses these readings to
implement a PID algorithm to balance the segway by controlling the forward/backward drive of two motor cells. The segway also has two load cells measuring the relative 
weight of the rider to ensure balance and safety for the duration of the ride. Users start the segway by connecting to a bluetooth chip which uses UART communication 
to enter the riding and steering states. We use a SPI protocol to communicate with the segway's physical devices.
