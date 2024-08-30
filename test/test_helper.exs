Mox.defmock(InstructorLite.HTTPClient.Mock, for: InstructorLite.HTTPClient)
Mox.defmock(MockAdapter, for: InstructorLite.Adapter)

# Exclude the unmocked tests by default
ExUnit.configure(exclude: :integration)

ExUnit.start()
