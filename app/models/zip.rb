class Zip
  include ActiveModel::Model

  attr_accessor :id, :city, :state, :population

  def to_s
    "#{@id}: #{@city}, #{@state}, pop=#{@population}"
  end

  # initialize from both a Mongo and Web hash
  def initialize(params={})
    #switch between both internal and external views of id and population
    @id=params[:_id].nil? ? params[:id] : params[:_id]
    @city=params[:city]
    @state=params[:state]
    @population=params[:pop].nil? ? params[:population] : params[:pop]
  end

  # tell Rails whether this instance is persisted
  def persisted?
    !@id.nil?
  end
  def created_at
    nil
  end
  def updated_at
    nil
  end

  # convenience method for access to client in console
  def self.mongo_client
   Mongoid::Clients.default
  end

  # convenience method for access to zips collection
  def self.collection
   self.mongo_client['zips']
  end

  # implement a find that returns a collection of document as hashes. 
  # Use initialize(hash) to express individual documents as a class 
  # instance. 
  #   * prototype - query example for value equality
  #   * sort - hash expressing multi-term sort order
  #   * offset - document to start results
  #   * limit - number of documents to include
  def self.all(prototype={}, sort={:population=>1}, offset=0, limit=100)
    #map internal :population term to :pop document term
    tmp = {} #hash needs to stay in stable order provided
    sort.each {|k,v| 
      k = k.to_sym==:population ? :pop : k.to_sym
      tmp[k] = v  if [:city, :state, :pop].include?(k)
    }
    sort=tmp

    #convert to keys and then eliminate any properties not of interest
    prototype=prototype.symbolize_keys.slice(:city, :state) if !prototype.nil?

    Rails.logger.debug {"getting all zips, prototype=#{prototype}, sort=#{sort}, offset=#{offset}, limit=#{limit}"}

    result=collection.find(prototype)
          .projection({_id:true, city:true, state:true, pop:true})
          .sort(sort)
          .skip(offset)
    result=result.limit(limit) if !limit.nil?

    return result
  end

  #implememts the will_paginate paginate method that accepts
  # page - number >= 1 expressing offset in pages
  # per_page - row limit within a single page
  # also take in some custom parameters like
  # sort - order criteria for document
  # (terms) - used as a prototype for selection
  # This method uses the all() method as its implementation
  # and returns instantiated Zip classes within a will_paginate
  # page
  def self.paginate(params)
    Rails.logger.debug("paginate(#{params})")
    page=(params[:page] ||= 1).to_i
    limit=(params[:per_page] ||= 30).to_i
    offset=(page-1)*limit
    sort=params[:sort] ||= {}

    #get the associated page of Zips -- eagerly convert doc to Zip
    zips=[]
    all(params, sort, offset, limit).each do |doc|
      zips << Zip.new(doc)
    end

    #get a count of all documents in the collection
    total=all(params, sort, 0, 1).count
    
    WillPaginate::Collection.create(page, limit, total) do |pager|
      pager.replace(zips)
    end    
  end

  # locate a specific document. Use initialize(hash) on the result to 
  # get in class instance form
  def self.find id
    Rails.logger.debug {"getting zip #{id}"}

    doc=collection.find(:_id=>id)
                  .projection({_id:true, city:true, state:true, pop:true})
                  .first
    return doc.nil? ? nil : Zip.new(doc)
  end 

  # create a new document using the current instance
  def save 
    Rails.logger.debug {"saving #{self}"}

    self.class.collection
              .insert_one(_id:@id, city:@city, state:@state, pop:@population)
  end

  # update the values for this instance
  def update(updates)
    Rails.logger.debug {"updating #{self} with #{updates}"}

    #map internal :population term to :pop document term
    updates[:pop]=updates[:population]  if !updates[:population].nil?
    updates.slice!(:city, :state, :pop) if !updates.nil?

    self.class.collection
              .find(_id:@id)
              .update_one(:$set=>updates)
  end

  # remove the document associated with this instance form the DB
  def destroy
    Rails.logger.debug {"destroying #{self}"}

    self.class.collection
              .find(_id:@id)
              .delete_one   
  end  
end
