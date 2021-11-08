/**
* Name: MBA_AE_with_DC
* Author: Sebastian Schmid
* Description: Local communication for MBAs using anti-entropy with push-pull AND death certificates
* Tags: 
*/


@no_warning
model MBA_AE_with_DC

import "../../Station_Item.gaml" 
global{	
	
	string communication_mode <- "PUSH-PULL"; //PUSH, PULL or PUSH-PULL
	
	//knowledge spread stuff
	list<string> tpid;
	float avg_traffic <-0 ; // sum of avg msgs per transporter / amount transporters
	
	
	init{
		create transporter number: no_transporter;		
		
		write "Agent communication mode is set to " + communication_mode color:#black ;	
		write "Distrubance cycle is " + disturbance_cycles;
		
		ask transporter{
			add name to: tpid;
		}

	}
	
	reflex knowledge_spread	when:(length(tpid) != 0){
		ask transporter {
			
			if(agent_model = truth){
				remove name from: tpid;
			}
		}		
		
		if(length(tpid) = 0)
		{
			write "All transporters know the truth -- " + cycle;
		} 
	}
	
	reflex reset_tpid when: (cycle > 1) and every(disturbance_cycles){
		ask transporter{
			add name to: tpid;
		}		
	}
	
	reflex update_avg_traffic{
		float sum_of_all <-0;
		
		ask transporter{
			
			//sum_of_all <- sum_of_all + (total_traffic / amt_of_cycles_when_communicated);
			sum_of_all <- sum_of_all + ((amt_of_cycles_when_communicated = 0) ? 0 : (total_traffic / amt_of_cycles_when_communicated));
		}
		
		avg_traffic <- sum_of_all / float(no_transporter); //avg traffic over all transporters per cycle
		
	}
	
}

//##########################################################
//schedules agents, such that the simulation of their behaviour and the reflex evaluation is random and not always in the same order 
species scheduler schedules: shuffle(item+station+transporter);

species transporter parent: superclass schedules:[]{
	
	item load <- nil;
	
	/*A station can be described by agent_model & a timestamp*/
	map<rgb, point> agent_model <- []; //model about positions of already found or communicated stations. Entries have shape [rgb::location] 
	map<rgb, int> timestamps <- []; //save the most recent point in time when an agent learned or observed about an station. [rgb::int]
	map<rgb, int> deathcertificates <- []; // holds death certificates to indicate wrong inforamtion ("absence of items") and timestamps
	
	float total_traffic <- 0; //average amount of messages sent to communicate 
	float amt_of_cycles_when_communicated <-0; 
	
	init{
		
	}
	
	//actively check surroundings for stations and note down perceived facts
	reflex check_surroundings_for_model when:(agents_inside(my_cell.neighbors) of_species station){
			
		station stat <-  first(agents_inside(my_cell.neighbors) of_species station); //gets the first station that is next to a transporter
		
		do add_station_to_model(stat); //Adds a station to the tranporter's model, updates entries and checks for duplicates
				
	}
	
	
	//%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
	
	/*Demers et al. also discuss a limitation of connections to reduce the overall traffic (e.g. the limit the exchange to only 1 other database). They use it because of "realism reasons", as there might be lots of sites to update. 
	 * Here, as out neighbors are per se only a small subset of the overall transporter population, we do not include another artificial limitation and rather consider all available exchange partners instead.
	 */
	
	//actively check surroundings for other agent and PUSH-PULL knowledge about observations
	reflex PUSH_PULL_to_nearby_neighbors when: (!empty(agents_inside(my_cell.neighbors) of_species transporter) and (communication_mode = "PUSH-PULL")) {
		
		list<transporter> neighboring_agents <-  agents_inside(my_cell.neighbors) of_species transporter; //returns list of all other transporters inside surroundings
		int tmp_traffic <- 0 ;//holds amt of sent msgs this cycle
		
		//Demers et al. take SOME of the other databases; we consider neighbors to all for now
		
		ask neighboring_agents{
			
			//loop over model	
			loop col over: self.timestamps.keys {
				
				if(((myself.timestamps at col) > (self.timestamps at col)) or !(self.timestamps.keys contains col)){
					//PUSH
					
					if((self.deathcertificates.keys contains col) and (self.deathcertificates at col >= myself.timestamps at col)){
						add (self.deathcertificates at col) at:col to: myself.deathcertificates; //save DC with timestamps - do not alter own agent model
						
					} else if((self.deathcertificates.keys contains col) and (self.deathcertificates at col < myself.timestamps at col)){
					
						add (myself.agent_model at col) at:col to: self.agent_model; //save color and position
						add (myself.timestamps at col) at:col to: self.timestamps; //save point in time of last information
						
						remove col from: self.deathcertificates; //remove DC from list
					
					}
					
				} else if(((myself.timestamps at col) < (self.timestamps at col)) or !(myself.timestamps.keys contains col)){
					//PULL								
					add (self.agent_model at col) at:col to: myself.agent_model; //save color and position
					add (self.timestamps at col) at:col to: myself.timestamps; //save point in time of last information
				
				
				}
				
				tmp_traffic <- tmp_traffic +1; //!! TODO: we only count one message for now, although its push and pull AND DCs might be sent around..?
			}
			
			//loop over DCs
			loop col over: self.deathcertificates.keys {
				
				if(((myself.deathcertificates at col) > (self.deathcertificates at col)) or !(self.deathcertificates.keys contains col)){
					//PUSH
					add (myself.deathcertificates at col) at:col to: self.deathcertificates; //save color and position
					//add (myself.timestamps at col) at:col to: self.timestamps; //save point in time of last information
				} else if(((myself.deathcertificates at col) < (self.deathcertificates at col)) or !(myself.deathcertificates.keys contains col)){
					//PULL								
					add (self.deathcertificates at col) at:col to: myself.deathcertificates; //save color and position
					//add (self.timestamps at col) at:col to: myself.timestamps; //save point in time of last information
				}
				
				tmp_traffic <- tmp_traffic +1; //TODO: we count one message for now, although its push AND pull. That would make TWO messages being sent between both agents. 
			}		
		}
		
		if(tmp_traffic != 0) //if !=0 --> communication took place 
		{
			do increase_traffic(tmp_traffic);
		}
	}
	
	//%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
	
	//after knowledge exchange with other agents, check our model for contradictions
	//--> every position may only be used once. Check if it is used more than one time. If so, eliminate all duplicates with older timestamps.
	reflex consistency_check when:true {
		
		
		loop dc over: deathcertificates.keys{
			
			if((timestamps.keys contains dc) and (deathcertificates at dc >= timestamps at dc)) {
				
				//DC is more recent, remove entry from model
				remove dc from: timestamps;
				remove dc from: agent_model;
				
			} else if((timestamps.keys contains dc) and (deathcertificates at dc < timestamps at dc)){
				//model is more recent, remove DC from dc list
				remove dc from: deathcertificates;
			}
			
		}
		
		loop stat over: agent_model.keys{	

			list<rgb> duplicates <- agent_model.keys where (agent_model at each = (agent_model at stat)); //get all stations that point to the same position		

			duplicates <- duplicates sort_by (timestamps at each); //sort in ascending order, means last is most recent ///???? 
			
			duplicates <- duplicates - last(duplicates);
				
			//remove all other duplicates
			loop dup over: duplicates {
				
				remove key: dup from: agent_model; //remove entry from agent's model
				remove key: dup from: timestamps; //remove entry from observation timestamps
				
				add cycle at:dup to: deathcertificates; //save that this information was outdated 	 	
			}
		
		}
		
	}
	
	/*After surroundings, other agents and internal model have been checked, apply respective actions with up-to-date knowledge acc. to my model*/
	//if i am empty or do not know where my item's station is -> wander
	reflex random_movement when:((load = nil) or ((load != nil) and !(agent_model contains_key load.color))) {
		
		//generate a list of all my neighbor cells in a random order
		list<shop_floor> s <- shuffle(my_cell.neighbors); //get all cells with distance ONE
		
		loop cell over: s{ //check all cells in order if they are already taken.
			if(empty(transporter inside cell) and empty(station inside cell)) //as long as there is no other transporter or station
			{
				do take_a_step_to(cell); //if the cell is free - go there		
			}
		}
	}
	
	//if I transport an item and know it about the station, I'll go to nearest neighboring field of this station 
	reflex exact_movement when:((load != nil) and (agent_model contains_key load.color)) {
				
		shop_floor target <- shop_floor(agent_model at load.color); //Key of pair contains the position. Target is the station itself, but we will not enter the stations cell. When we are next to it, our item will be loaded off, s.t. we won't enter the station 
		
		//contains neighboring cells in ascending order of distance, meaning: first cell has least distance
		list<shop_floor> options <- my_cell.neighbors sort_by (each distance_to target);
		
		loop while:!empty(options){ //check all options in order if they are already taken.
			
			shop_floor cell <- first(options);
			
			if(empty(transporter inside cell) and empty(station inside cell)) //as long as there is no other transporter or station
			{
				do take_a_step_to(cell); //if the cell is free - go there
				break;		
			}else{
				
				//remove unreachable cell from option. Sort rest.
				options <- options - cell;
				options <- options sort_by (each distance_to target);
			}
			
		}
		
	}	
	
	//this reflex is for the case that I have a thing and am now looking for a station. Up to now, i DO NOT have to queue
	reflex get_rid_of_thing when: (load != nil){			
		//get the first cell with a station on it that is adjacent to me
		shop_floor cell_tmp <- (my_cell.neighbors) first_with (!(empty(station inside (each)))); //only ONE (the first cell...)
		list<shop_floor> cell_tmp_list <- (my_cell.neighbors) where (!(empty(station inside (each)))); //get all stations 
		
		//check all adjacent cells with stations inside 
		loop cell over: cell_tmp_list{
			
			station s <- one_of(station inside cell); //there should only be one station per cell, but this ensures that only one is picked.
		
			//if the station we picked has the color of our item
			if(s.accept_color = load.color) {
				
				/*Update all variables and containers for investigations*/
					put delivered[load.color]+1 key:load.color in: delivered; //count as delivered in respective colo category
					total_delivered <- total_delivered +1; //increase counter for total amount of delivered things by 1
					
					//add current cycle to thing to denote time when it was delivered
					load.cycle_delivered <- cycle; //sent new cycle as state to load
					int cycle_difference <- load.cycle_delivered - load.cycle_created; //calculate the cycle difference to add it to the evaluation variables in the next step
					time_to_deliver_SUM <- time_to_deliver_SUM + cycle_difference ; //add it to the total sum
					mean_of_delivered_cycles <- time_to_deliver_SUM/(total_delivered); //after successful delivery, update average amount of cycles
		
				do deliver_load(); //load is delivered
				do add_station_to_model(s); //as delivery was successful, we add the observation right now to our model
				
				break; //as we have loaded off our item, we do not need to check any leftover stations (also it would lead to an expection because load is now nil)
			}
		}		
	}
	
	//search adjacency for a station. If it has a thing, pick it up. Depending in stigmergy settings, also initiate color marks
	reflex search_thing when: load = nil{			
		//get the first cell with a station on it that is adjacent to me
		shop_floor cell_tmp <- (my_cell.neighbors) first_with (!(empty(station inside (each))));
		
		if(cell_tmp != nil) //if this cell is NOT empty, the transporter has a station neighbor
		{
			station s <- first(station inside cell_tmp); //cells can only have one station at a time, hence this list has exactly one entry. 'First' is sufficient to get it.
									
			//Request state of s to ask about storage. if this NOT nil, a thing has been created and is waiting there and assigned as load.
			load <- s.storage; //take over thing as load from here 
			
			if( load != nil){
				
				//if load is NOT nil now, we took something over. If it would still be nil, then the station was simply empty
				s.storage <- nil; //we took the thing, thus set station's storage to nil
				//Remark: here used to be an update for the load's location, but as the reflex for updating the thing follows immediately after this reflex here, we don't need it
			}
			
		}		
	}
		
	reflex update_thing when: (load != nil){
		ask load{
				my_cell <- myself.my_cell; //just ask the thing you carry to go to the same spot as you.
				location <- myself.my_cell.location;
			}			
	}
	
	action increase_traffic(int new_val){
		total_traffic <- total_traffic +new_val;	//update total amount of send msgs
		amt_of_cycles_when_communicated <- amt_of_cycles_when_communicated +1;//increase counter by 1
	}

		
	action deliver_load{
		
		ask load{
			do die;
		}

		load<-nil; //reset load after delivery
	}
	
	action take_a_step_to(shop_floor cell){
				
		my_cell <- cell; //if the cell is free - go there
		location <- my_cell.location;
		
	}

	/*Adds an entry to the MBAs model, updates entries and checks for duplicates*/ 		
	action add_station_to_model(station stat){
		
		//new entry
		if(!(agent_model contains_key stat.accept_color)) //if no observation has been made before
		{
		
			add stat.location at:stat.accept_color to: agent_model; //save color and position
			add cycle at:stat.accept_color to: timestamps; //save point in time of last information
			
		} else { //obviously an observation has been made before then, but anyways //if(agent_model contains_key stat.accept_color)
			
			//check if still same
			if((agent_model at stat.accept_color) = stat.location)
			{
				//everything still the same. Update time to current cycle, because observation is still valid and recent.

				//TODO: We DO NOT update our observation - as it is still the same, the fact we observed in the past is obviously still valid and not a new fact!!
				/////add cycle at:stat.accept_color to: timestamps;
				/////ALSO, there is no update of the hot topics list here - still old stuff...
				
			} else { //Agent knows about this station, but it isn't where it says in the model 

				//Agent knew about station before, but it has changed! Hence, update the model (as this is obvious, observed truth)
				add stat.location at:stat.accept_color to: agent_model; //save color and position
				add cycle at:stat.accept_color to: timestamps; //save point in time of observation
				
				//By design, every station exists only once. This means that we should check, if there are now TWO (or more!) entries in the model, which contradict each other. 
				//As our most recent update has been observed just now and observations outweigh implicated, contradicting untruths we issue DELETE all other contradicting information
				
				//search for other occurences of this location - and issue a DC, if I already know that this location is taken - plus ignore CURRENT observed station from above //
				list<rgb> duplicates <- agent_model.keys where (agent_model at each = stat.location);		
				
				duplicates <- duplicates - stat.accept_color; //as agent has just observed the stat with its color it is clear that it would occur in this list, hence remove it (it is the most recent entry...)
					
				//remove all other duplicates
				loop dup over: duplicates {
					
					remove key: dup from: agent_model; //remove entry from agent's model
					remove key: dup from: timestamps; //remove entry from observation timestamps
					
					add cycle at:dup to: deathcertificates; //save that this information was outdated 	
				}
			}
		}
	}
	
	aspect base{
		
		draw circle(cell_width) color: #grey border:#black;
	}
	
	aspect info{
		
		draw circle(cell_width) color: #grey border:#black;
		draw replace(name, "transporter", "") size: 10 at: location-(cell_width) color: #red;
	}	
}

//##########################################################
experiment MBA_AE_with_DC_No_Charts type:gui{
		
	parameter "Disturbance cycles" category: "Simulation settings" var: disturbance_cycles<-100;  
	parameter var: width<-25; //25, 50, 100	
	parameter var: cell_width<- 2.0; //2.0, 1.0 , 0.5
	parameter "No. of transporters" category: "Transporter" var: no_transporter<-17 ; // 17, 4*17, 8*17
	parameter "No. of stations" category: "Stations" var: no_station<-16; //4, 4*4 (16), 4*4*4 (64)
	
	
	output {	
		layout #split;
		 display "Shop floor display" { 
				
		 		grid shop_floor lines: #black;
		 		species shop_floor aspect:position;
		 		species transporter aspect: info;
		 		species station aspect: base;
		 		species item aspect: base;
	
		 }
		 
		  inspect "Agent_Model" value: transporter attributes: ["agent_model"] type:table;
		  inspect "Timestamps" value: transporter attributes: ["timestamps"] type:table;
		  inspect "DCs" value: transporter attributes: ["deathcertificates"] type:table;
		  
	 }
	 
	
}

experiment MBA_AE_with_DC type: gui {
	// Define parameters here if necessary
	
	parameter "Disturbance cycles" category: "Simulation settings" var: disturbance_cycles<-300;  
	parameter var: width<-25; //25, 50, 100	
	parameter var: cell_width<- 2.0; //2.0, 1.0 , 0.5
	parameter "No. of transporters" category: "Transporter" var: no_transporter<-17 ; // 17, 4*17, 8*17
	parameter "No. of stations" category: "Stations" var: no_station<-16; //4, 4*4 (16), 4*4*4 (64)
	
	
	//Define attributes, actions, a init section and behaviors if necessary
	
	output {

	layout #split;
	 display "Shop floor display" { 
			
	 		grid shop_floor lines: #black;
	 		species transporter aspect: base;
	 		species station aspect: base;
	 		species item aspect: base;

	 }	 
	  
	display statistics{
						
			chart "Mean cycles to deliver" type:series size:{1 ,0.5} position:{0, 0}{
					data "Mean of delivered cycles" value: mean_of_delivered_cycles color:#purple marker:false ;		
			}

	 }
	
	 display delivery_information refresh: every(20#cycles){
			 
			chart "total delivered things" type: series size: {1, 0.5} position: {0,0}{				
				data "total delivered things" value: total_delivered color:#red marker:false; 

			}
			
									 
			chart "Delivery distribution" type:histogram size:{1 ,0.5} position:{0, 0.5} {
					//datalist takes a list of keys and values from the "delivered" map  
					datalist delivered.keys value: delivered.values color:delivered.keys ;
			}
		}	
	}
  
}

/*Runs an amount of simulations in parallel, keeps the seeds and gives the final values after 10k cycles*/
experiment MBA_AE_with_DC_batch type: batch until: (cycle >= 10000) repeat: 40 autorun: true keep_seed: true{

	
	reflex save_results_explo {
    ask simulations {
    	
    	float mean_cyc_to_deliver <- ((self.total_delivered = 0) ? 0 : self.time_to_deliver_SUM/(self.total_delivered)); //
    	
    	save [int(self), self.seed, disturbance_cycles ,self.cycle, self.total_delivered, mean_cyc_to_deliver]
          to: "result/3_MBA_GOSSIP_results.csv" type: "csv" rewrite: false header: true; 
    	}       
	}		
}

/*Runs an amount of simulations in parallel, varies the the disturbance cycles from 25 to 500 and gives the final values after 10k cycles*/
experiment MBA_AE_with_DC_var_batch type: batch until: (cycle >= 10000) repeat: 40 autorun: true keep_seed: true{ 

	parameter "Disturbance cycles" category: "Simulation settings" var: disturbance_cycles among: [25#cycles, 50#cycles, 100#cycles, 250#cycles, 500#cycles]; //amount of cycles until stations change their positions
	
	parameter var: width<-25; //25, 50, 100	
	parameter var: cell_width<- 2.0; //2.0, 1.0 , 0.5
	parameter "No. of transporters" category: "Transporter" var: no_transporter<-17 ; // 17, 4*17, 8*17
	parameter "No. of stations" category: "Stations" var: no_station<-4; //4, 4*4 (16), 4*4*4 (64)
	
	
	reflex save_results_explo {
    ask simulations {
    	
    	float mean_cyc_to_deliver <- ((self.total_delivered = 0) ? 0 : self.time_to_deliver_SUM/(self.total_delivered)); //
    	
    	save [int(self), self.seed, disturbance_cycles, self.cycle, self.total_delivered, mean_cyc_to_deliver] //..., ((total_delivered = 0) ? 0 : time_to_deliver_SUM/(total_delivered)) 
           to: "result_var/"+string(width)+"_ae_DC.csv" type: "csv" rewrite: false header: true; //rewrite: (int(self) = 0) ? true : false
    	}       
	}		
}
