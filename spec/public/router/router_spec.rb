require File.join(File.dirname(__FILE__), "spec_helper")

describe Merb::Router do

  describe "#match" do
    
    it "should raise an error if the routes were not compiled yet" do
      lambda { Merb::Router.match(simple_request) }.should raise_error(Merb::Router::NotCompiledError)
    end
    
  end


end

__END__
# These are all out of date
describe "Merb::Router" do
  
  it "should work when no routes were defined" do
    pending "This doesn't work yet" do
      Merb::Router.prepare { |r| }
      route_to("/hello/world").should be_empty
    end
  end
  
end