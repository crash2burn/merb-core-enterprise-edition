require File.join(File.dirname(__FILE__), '..', "spec_helper")

describe "When generating URLs," do
  
  class ORM ; end
  
  class Article < ORM 
    def id   ; 10        ; end
    def to_s ; "article" ; end
  end
  
  class Account < ORM
    def to_s ; "account"  ; end
    def url  ; "/awesome" ; end
  end
  
  class User    < ORM
    def to_s ; "user" ; end
    def name ; "carl" ; end
  end
  
  class Resource
    def to_s ; "hello" ; end
  end
  
  before(:each) do
    Merb::Router.prepare do
      identify Account => :url, User => :name, ORM => :id do
        match("/:account") do
          resources :users
        end
      end
      
      match("/resources/:id").register.name(:resource)
    end
  end
  
  describe "a route with custom identifiers" do
    
    it "should use #to_s if no other identifier is set" do
      url(:resource, :id => Article.new).should  == "/resources/article"
      url(:resource, :id => Account.new).should  == "/resources/account"
      url(:resource, :id => User.new).should     == "/resources/user"
      url(:resource, :id => Resource.new).should == "/resources/hello"
    end
    
    it "should use the identifier for the object" do
      url(:user, :account => Account.new, :id => User.new).should == "/awesome/users/carl"
    end
    
  end
  
end