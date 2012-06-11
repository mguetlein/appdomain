require 'rubygems'
require 'opentox-ruby'

require 'app_domain.rb'

post '/:app_domain_alg/:id' do
  model = AppDomain::AppDomainModel.get(params[:id])
  raise OpenTox::NotFoundError.new("app-domain-model '#{params[:id]}' not found.") unless model
  [:dataset_uri].each do |p|
    raise OpenTox::BadRequestError.new("#{p} missing") unless params[p].to_s.size>0
  end
  LOGGER.debug "applying appdomain model #{model.uri} with params #{params.inspect}"

  dataset = model.find_predicted_model(params[:dataset_uri])
  if dataset
    LOGGER.debug "found already existing prediction dataset #{dataset}"
    dataset
  else
    task = OpenTox::Task.create( "Apply Model #{model.uri}", url_for("/", :full) ) do |task|
      model.apply(params[:dataset_uri], task)
    end
    return_task(task)
  end
end

post '/:app_domain_alg' do
  [:dataset_uri, :prediction_feature].each do |p|
    raise OpenTox::BadRequestError.new("#{p} missing") unless params[p].to_s.size>0
  end
  LOGGER.debug "building app-domain model with params #{params.inspect}"
  
  model = AppDomain::AppDomainModel.find_model(params)
  if model
    LOGGER.debug "found already existing model #{model}"
    model
  else
    task = OpenTox::Task.create( "Create Model", url_for("/", :full) ) do |task|
      model = AppDomain::AppDomainModel.create(params,@subjectid)
      model.build(task)
      model.uri
      end
    return_task(task)
  end  
end

get '/?' do
  uri_list = AppDomain::AppDomainModel.all.sort.collect{|v| v.uri}.join("\n") + "\n"
  if request.env['HTTP_ACCEPT'] =~ /text\/html/
    content_type "text/html"
    OpenTox.text_to_html uri_list,@subjectid
  else
    content_type "text/uri-list"
    uri_list
  end
end

get '/:app_domain_alg/:id' do
  model = AppDomain::AppDomainModel.get(params[:id])
  raise OpenTox::NotFoundError.new("app-domain-model '#{params[:id]}' not found.") unless model
  case request.env['HTTP_ACCEPT']
  when "application/rdf+xml"
    content_type "application/rdf+xml"
    model.to_rdf
  when /text\/html/
    model.inspect
    OpenTox.text_to_html model.to_yaml
  else
    raise "not yet implemented"
  end  
end

delete '/:app_domain_alg/:id' do
  model = AppDomain::AppDomainModel.get(params[:id])
  raise OpenTox::NotFoundError.new("app-domain-model '#{params[:id]}' not found.") unless model
  model.delete
  content_type "text/plain"
  "deleted model with id #{params[:id]}\n"
end

get '/:app_domain_alg/:id/predicted/:prop' do
  model = Weka::WekaModel.get(params[:id])
    raise OpenTox::NotFoundError.new("app-domain-model '#{params[:id]}' not found.") unless model
  model.subjectid = @subjectid
  if params[:prop] == "value"
    feature = model.prediction_value_feature
  else
    raise OpenTox::BadRequestError.new "Unknown URI #{@uri}"
  end
  case @accept
  when /yaml/
    content_type "application/x-yaml"
    feature.metadata.to_yaml
  when /rdf/
    content_type "application/rdf+xml"
    feature.to_rdfxml
  when /html/
    content_type "text/html"
    OpenTox.text_to_html feature.metadata.to_yaml
  else
    raise OpenTox::BadRequestError.new "Unsupported MIME type '#{@accept}'"
  end
end



