require File.join(File.dirname(__FILE__), "spec_helper")

describe Merb::Router do

  describe "#match" do
    
    it "should raise an error if the routes were not compiled yet" do
      lambda { Merb::Router.match(simple_request) }.should raise_error(Merb::Router::NotCompiledError)
    end
    
  end


end