Mox.defmock(Instructor.HTTPClient.Mock, for: Instructor.HTTPClient)
Mox.defmock(MockAdapter, for: Instructor.Adapter)

# Exclude the unmocked tests by default
ExUnit.configure(exclude: :integration)

ExUnit.start()
