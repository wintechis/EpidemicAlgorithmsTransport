/**
* Name: MBA_Entropy
* Author: Sebastian Schmid
* Description: Local communication for MBAs using anti-entropy (Demers)
* Tags: 
*/


@no_warning
model MBA_Entropy

import "Station_Item.gaml"

global{	
	
	init{
		create transporter number: no_transporter;				
	}
}



//##########################################################
//schedules agents, such that the simulation of their behaviour and the reflex evaluation is random and not always in the same order 
species scheduler schedules: shuffle(item+station+transporter);


species transporter parent: superclass schedules:[]{
	item load <- nil;
	
	/*A station can EITHER be described by agent_model & a timestamp, XOR a death certificate - it MUST NOT be in both states*/
	map<rgb, point> agent_model <- []; //model about positions of already found or communicated stations. Entries have shape [rgb::location] 
	map<rgb, int> timestamps <- []; //save the most recent point in time when an agent learned or observed about an station. [rgb::int]
	map<rgb, int> death_certificates <- []; //death certificates for untruths and the time we learned about this. [rgb::int]
	
	init{
		
	}
	
	//actively check surroundings for stations and note down perceived facts
	reflex check_surroundings_for_model when:(agents_inside(my_cell.neighbors) of_species station){
		
		
		station stat <-  first(agents_inside(my_cell.neighbors) of_species station); //gets the first station that is next to a transporter
		
		do add_station_to_model(stat); //Adds a station to the tranporter's model, updates entries and checks for duplicates
				
	}
	
	/*Check overall model for contradictions (aka pointing to same location) and issue DCs if necessary - also check if there exist DCs and model entries at the same time*/
	reflex check_internal_model_for_consistency {
		/*By design, every station exists only once. This means that we should check the WHOLE MODEL (independent of observations), if there are contradictions*/
		
		loop stat over: agent_model.keys{			
			
			//check if this knowledge in the model has NO entry in the DC list - if so, check which is more recent and correct if necessary
			if(death_certificates.keys contains stat)
			{
				//there exists an entry for a DC, which means there has been an observation that SOMETIME information about this station was outdated
				
				if((timestamps at stat) >= (death_certificates at stat)){//if my knowledge is newer than my DC, delete the DC
					
					remove stat from: death_certificates;
					
				} else if ((timestamps at stat) < (death_certificates at stat)){////if I have a DC that indicates that my knowledge is outdated, delete my knowledge
					remove stat from: agent_model;
					remove stat from: timestamps;
					//as the DC is already there, we don't have to add it again to our own DC list...
					
					break; //as this knowledge is officially outdated, we do not check for duplicates below and skip right away
				}
				
			}		
			
			int amt_of_duplicates <- agent_model.keys count ((agent_model at each) = (agent_model at stat)); //how many other entries have the same value (aka position) as this station?
			
			if(amt_of_duplicates > 1) //If there is more than one entry, we have contradicting information 
			{
				//Keep the one with the most recent entry, for all others issue DCs
				list<rgb> duplicates <- (agent_model.keys where ((agent_model at each) = (agent_model at stat)));
				
				duplicates <- duplicates sort_by (timestamps at each); //order in ASCENDING fashion according to timestamps, s.t. most recent entry is now LAST
				duplicates <- duplicates - last(duplicates); //remove last item, aka the most recent observation. Still every color exists only once 
				//remove all other duplicates and declare them as DCs
				 
				loop dup over: duplicates {
					
					add cycle at:dup to: death_certificates; //issue a death certificates with current cycle to indicate when contradiction has been found
					
					remove key: dup from: agent_model; //remove entry from agent's model
					remove key: dup from: timestamps; //remove entry from observation timestamps 
					
				}	
			}				
		}
	}
	
	//actively check surroundings for other agent and exchange knowledge about observations and current death certificates
	reflex exchange_with_nearby_agents when: (agents_inside(my_cell.neighbors) of_species transporter) {
		
		list<transporter> neighboring_agents <-  agents_inside(my_cell.neighbors) of_species transporter; //returns list of all other transporters inside adjacency
		
		loop neighbor over: neighboring_agents {
			//We are actively PUSH-ing our knowledge to neighbors in an anti-entropy fashion. Other approaches would be e.g. only PUSH-PULL/PULL. (as described by Demers et al. 1987)
			
			//offer my model. Let neighbor pick and amend AND reject, if DCs are present 
			
			ask neighbor{
				
				//Terminology: "agent" = the entity that called this reflex (myself). "neighbor" = the entity that is adjacent and adressed by the "agent" (self)
				
				list<rgb> knows_about <- self.agent_model.keys; //what this neighbor knows about
				
				list<rgb> does_not_know <- myself.agent_model.keys - knows_about; //what the agent knows MINUS the things the neighbor knows is that what the neighbor lacks, aka knowledge the agent will propose to the neighbor
				
				/**UPDATED knowledge*/
				list<rgb> both_knowledge <- myself.agent_model.keys - does_not_know; //what BOTH this agent and its neighbor know
				
				loop same_know over:both_knowledge {
					//as both know already about a station, we need to check if they point to the same location
					//if they do - just use the latest cycle to update the observation
					if(self.agent_model at same_know = myself.agent_model at same_know){ //get both locations and check
							
							if(self.timestamps at same_know > myself.timestamps at same_know) //neighbor is more recent than we are
							{
								add (self.timestamps at same_know) at: same_know to: myself.timestamps; //use neighbor's timestamps
							}else{ //we are more recent than our neighbor
								add (myself.timestamps at same_know) at: same_know to: self.timestamps; //use agent's timestamps
							}
					//we DO both know about the same station, but our location obersvations do not match! -- if they don't the one with the older observation loses and gets an update of location and timestamp
					} else if (self.agent_model at same_know != myself.agent_model at same_know){ 

							//take more recent one and overwrite the other
							if(self.timestamps at same_know > myself.timestamps at same_know) //neighbor is more recent than agent
							{
								//use neighbor's values
								add (self.timestamps at same_know) at: same_know to: myself.timestamps;
								add (self.agent_model at same_know) at: same_know to: myself.agent_model;
							}else{ //agnet is more recent than neighbor
								//use agent's values
								add (myself.timestamps at same_know) at: same_know to: self.timestamps;
								add (myself.agent_model at same_know) at: same_know to: self.agent_model;
							}
					}				
				}
				
				/**CHECK Death Certificates*/							
				//take list of does_not_know (= stations the neighbor has NO secured knowledge about) and compare with neighbors DCs (= neighbor has knowledge that information about this station MIGHT be wrong) --> information is disputed
				list<rgb> disputed_stations <- does_not_know where (self.death_certificates.keys contains each); //gather entries that also appear in neighbors DC list, hence are disputed
				
				//resolve disputes for death certificates
				loop dispute over: disputed_stations{
					int agent_time <- myself.timestamps at dispute; //get cycle of observed truth
					int neigh_time <- self.death_certificates at dispute; //get cycle of observed death / disturbance
					
					if((agent_time > neigh_time) or (agent_time = neigh_time)){//agent observed truth is more recent (which it is ALSO ON A TIE!!)
						
						remove key:dispute from: self.death_certificates; //remove entry from neighbor's DC list as it is deprecated
					} else if (agent_time < neigh_time){//neighbor's DC information is more up to date
						
						remove key:dispute from: myself.agent_model; //delete this knowledge from agent's model
						remove key:dispute from: myself.timestamps; //delete this knowledge from agent's timestamps
						add neigh_time at: dispute to: myself.death_certificates; //add respective neighbor's DC with timestamps to agent's DCs
						
						//kick from "does not know", as agent lacked information before, s.t. it won't be checked later on 
						remove dispute from: does_not_know; 		
					} 
				}
				
				/**NEW knowledge - knowledge from which we KNOW that neither partner carries a DC about or disupted (as agent always checks its own model AND neighbor just checked its DCs in the step above)*/
				loop new_knowledge over: does_not_know{
					
					//sanity check to see, if this knowledge might also be (unknowingly!) outdated (e.g. the agent hasn't met someone with a respective DC before and now we would have two entries that point to the same location...)
					/*Explanation:
					 *We want to add DEFINITIVE new knowledge - a station color that has not been known before and its location. If the neighbor notices know, that this new knowledge is already used (the location), which is assumed to be unique,
					 * there must be another DISPUTE again, we have to solve. Per se, both observation are fine, as they have been actively made, but with time one could have been already outdated. Hence we assume uniqueness of our locations and
					 * compare the time stamps again. Whatever entry is older, is removed from the model and saved as DC.
					 */		
					
					point new_location <- myself.agent_model at new_knowledge;			
					if(self.agent_model.values contains new_location){ //DISPUTE detected as this LOCATION has already been used (= already appears in the neighbor's model's values)!. The station might be still new, but the location is the duplicate now. 
						
						/*!!! - THIS MIGHT GET VERY EXPENSIVE for lots of stations as we have to iterate through ALL entries*/						
						list<rgb> disputed_stations <- self.agent_model.keys where ((self.agent_model at each) = new_location);//detect neighbor's model keys to same value (aka the disputed one?)
						disputed_stations <- disputed_stations sort_by (self.timestamps at each); //sort in ASCENDING fashion according to timestamps, s.t. most recent dispute is now LAST 
						
						//now decide who is right in the dispute again: either agent or neighbor -- similar to above, but here only with observed truths and NOT with DCs
						//Then isse DCs about facts that are now know to be deprecated, either at the agent or the neighbor 
						
						int agent_time <- myself.timestamps at new_knowledge; //get cycle of observed truth in agent
						
						loop dispute over: disputed_stations{ //= list of stations that use the same location, sorted ascending w.r.t. the time of observation
							
							int neigh_time <- self.timestamps at dispute; //get cycle of observed truth in neighbor
							
							if((agent_time > neigh_time) or (agent_time = neigh_time)){//agent observed truth is more recent (which it is also on tie)
								
								remove key:dispute from: self.agent_model; //remove entry from neighbor's model as it is deprecated
								remove key:dispute from: self.timestamps; //remove entry from neighbor's timestamps as it is deprecated
								
								add agent_time at: dispute to: self.death_certificates; //issue a new DC for neighbor with timestamp of agent's observation (we can be sure that for THIS cycle the neighbor's observation was false)
								
								//add new knowledge FROM agent TO neighbor, as this knowledge is assured to be new to the neighbor
								add (myself.agent_model at new_knowledge) at: new_knowledge to: self.agent_model; //get known location from agent and add to neighbor
								add (myself.timestamps at new_knowledge) at: new_knowledge to: self.timestamps; //get timestamp of this observation and add to neighbor
								
										
							} else if (agent_time < neigh_time){//neighbors information is more up to date
								//we check disputes with the neighbor successively - until now, all disputes that were older than the agent have been removed (and DCs issued to neighbor). 
								//If there are disputes that are more recent than the agent's entry, the agent is wrong and it's entry has to be removed. 
								//The neighbor ONLY denies the acceptance of new knowledge and informs the agent that it is wrong, but it does NOT share its own knowledge (this would be PUSH-PULL) and we cannot guarantee that this shared knowledge is without dispute (duplicate, DC etc).
								//The neighbor as acting entitiy that shares its knowledge shall do so in its own, active cycle!  
								//!!!!!!!! We do NOT skip ahead here and pull from neighbor as we cannot be sure that this current neigbor entry is disupte free with the other neighbor entries. 
								//This will be done if the neighbor becomes the acting agent and then there is also a proper check for DCs and dupliactes. 
	
								//Attention: even if there is more than one more recent dispute left, we do not care about resolving them, as the acting entity in this call is the agent - not the neighbor. 
								//This would mean, that the neighbor's model contains duplicates as locations are used more than once. The neighbor has a reflex that will solve these duplicates in a subsequent step.
								//Here, we only care about the knowledge that the agent wants to exchange with its neighbors - not any resolving of disputes in the neighbor!! 
								
								remove key:new_knowledge from: myself.agent_model; //delete this "new" knowledge from agent model
								remove key:new_knowledge from: myself.timestamps; //delete this "new" knowledge from agent timestamps
								
								add neigh_time at: new_knowledge to: myself.death_certificates; //issue a new DC with the neighbors observation time for agent's "new" knowledge
								
								//it COULD be that in a previous step we added this "new" knowledge to the neighbor, only to find out NOW that it's depcrecated. Hence remove it, if added, and issue a DC
								remove key:new_knowledge from: self.agent_model; //delete this "new" knowledge from neighbor model
								remove key:new_knowledge from: self.timestamps; //delete this "new" knowledge from neighbor timestamps
								
								add neigh_time at: new_knowledge to: self.death_certificates; //issue a new DC to neighbor itself with observation time for agent's "new" knowledge
																
																						
								break; //as we SORTED all disputes in ASCENDING fashion, everything that comes AFTER this case is per definition more recent than the new_knowledge (which was hence declared deprecated and eliminated above) and can be skipped. 
								//The neighbor is responsible for the exchange of these entries and resolving its internal duplicates. 
							} 
						}
						//after all disputes have been cleared or only more recent entries via disputes are left, proceed with next new_knowledge 
						
					} else {//if there is nothing to dispute about, just take the new knowledge and add it to the neighbor
														
						add (myself.agent_model at new_knowledge) at: new_knowledge to: self.agent_model; //get known location from agent and add to neighbor
						add (myself.timestamps at new_knowledge) at: new_knowledge to: self.timestamps; //get timestamp of this observation and add to neighbor
					}					
				}
							
				/*EXCHANGE AND UPDATE death certificates as all disputes have been cleared above*/	
				//check all DCs of the agent and push them to the neighbor				
				loop dc over: myself.death_certificates.keys {
					
					if(!(self.death_certificates.keys contains dc)){//if this DC is unknown 
						//propose to add DC to neighbor's DC store
						//check for potential disputes if the model contains contradicting information - correct it right away
						if(self.agent_model.keys contains dc){
							
							//resolve dispute by comparing timestamps
							if((self.timestamps at dc) >= (myself.death_certificates at dc)){
								//neighbors KNOWLEDGE is more recent - delete agent's DC
								//again, we only refuse and DELETE the DC an do not propagate the neighbor's knowledge to the agent								
								remove dc from: myself.death_certificates;
								
							} else if ((self.timestamps at dc) < (myself.death_certificates at dc)){
								//agent's DC is more recent - delete neighbors knowledge
								
								add (myself.death_certificates at dc) at: dc to: self.death_certificates; //add agent's DC and its cycle to neighbor
								
								remove dc from: self.agent_model;
								remove dc from: self.timestamps;
								
							}
							
							
						} else if (!(self.agent_model.keys contains dc)){ //if there are no entries that might contradict the DC proposal, take it
								
							add (myself.death_certificates at dc) at: dc to: self.death_certificates; //add agent's DC and its cycle to neighbor
						}
					
					} else if(self.death_certificates.keys contains dc){ //if this DC is already known
						
						//update time of DC
						
						if((self.death_certificates at dc) < (myself.death_certificates at dc)){//if neighbor's DC has an older time stamps, update it
							add (myself.death_certificates at dc) at: dc to: self.death_certificates;
						} else if((self.death_certificates at dc) > (myself.death_certificates at dc)){ //if neighbor's DC is more up to date, pull it
							add (self.death_certificates at dc) at: dc to: myself.death_certificates;
						}
					}					
				}
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
			
			remove key:stat.accept_color from: death_certificates; //if there was a DC and we JUST made an observation, we remove this DC
			
		} else { //obviously an observation has been made before then, but anyways //if(agent_model contains_key stat.accept_color)
			
			//check if still same
			if((agent_model at stat.accept_color) = stat.location)
			{
				//everything still the same. Update time to current cycle, because observation is still valid and recent.
				add cycle at:stat.accept_color to: timestamps;
				
			} else { //Agent knows about this station, but it isn't where it says in the model 

				//Agent knew about station before, but it has changed! Hence, update the model (as this is obvious, observed truth)
				add stat.location at:stat.accept_color to: agent_model; //save color and position
				add cycle at:stat.accept_color to: timestamps; //save point in time of observation
				
				remove key:stat.accept_color from: death_certificates; //if there was a DC and we JUST made an observation, we remove this DC
				
				//By design, every station exists only once. This means that we should check, if there are now TWO (or more!) entries in the model, which contradict each other. 
				//As our most recent update has been observed just now and observations outweigh implicated, contradicting untruths we issue death certificate for all other contradictin information and write them down with the current cycle
				
				//search for other occurences of this location - and issue a DC, if I already know that this location is taken - plus ignore CURRENT observed station from above //
				list<rgb> duplicates <- agent_model.keys where (agent_model at each = stat.location);		
				
				duplicates <- duplicates - stat.accept_color; //as agent has just observed the stat with its color it is clear that it would occur in this list, hence remove it (it is the most recent entry...)
					
				//remove all other duplicates and declare them as DCs
				loop dup over: duplicates {
					add cycle at:dup to: death_certificates; //issue a death certificates with current cycle to indicate when contradiction has been found
					
					remove key: dup from: agent_model; //remove entry from agent's model
					remove key: dup from: timestamps; //remove entry from observation timestamps 	
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
experiment MBA_Entropy_No_Charts type:gui{
		
	parameter "Disturbance cycles" category: "Simulation settings" var: disturbance_cycles<-100;  
	parameter var: width<-25; //25, 50, 100	
	parameter var: cell_width<- 2.0; //2.0, 1.0 , 0.5
	parameter "No. of transporters" category: "Transporter" var: no_transporter<-17 ; // 17, 4*17, 8*17
	parameter "No. of stations" category: "Stations" var: no_station<-4; //4, 4*4 (16), 4*4*4 (64)
	
	
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
		  inspect "DCs" value: transporter attributes: ["death_certificates"] type:table;
		  
	 }
	 
	
}

experiment MBA_Entropy type: gui {
	// Define parameters here if necessary
	
	parameter "Disturbance cycles" category: "Simulation settings" var: disturbance_cycles<-100;  
	parameter var: width<-50; //25, 50, 100	
	parameter var: cell_width<- 1.0; //2.0, 1.0 , 0.5
	parameter "No. of transporters" category: "Transporter" var: no_transporter<-4*17 ; // 17, 4*17, 8*17
	parameter "No. of stations" category: "Stations" var: no_station<-4*4; //4, 4*4 (16), 4*4*4 (64)
	
	
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
			
			chart "Average thing lifespan" type:series size:{1 ,0.5} position:{0, 0.5}{
				
					data "Average thing lifespan" value: avg_thing_lifespan color: #blue marker: false;		
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
experiment MBA_Entropy_batch type: batch until: (cycle >= 10000) repeat: 40 autorun: true keep_seed: true{

	
	reflex save_results_explo {
    ask simulations {
    	
    	float mean_cyc_to_deliver <- ((self.total_delivered = 0) ? 0 : self.time_to_deliver_SUM/(self.total_delivered)); //
    	
    	save [int(self), self.seed, disturbance_cycles ,self.cycle, self.total_delivered, mean_cyc_to_deliver]
          to: "result/3_MBA_GOSSIP_results.csv" type: "csv" rewrite: false header: true; 
    	}       
	}		
}

/*Runs an amount of simulations in parallel, varies the the disturbance cycles from 25 to 500 and gives the final values after 10k cycles*/
experiment MBA_Entropy_var_batch type: batch until: (cycle >= 10000) repeat: 40 autorun: true keep_seed: true{ 

	parameter "Disturbance cycles" category: "Simulation settings" var: disturbance_cycles among: [25#cycles, 50#cycles, 100#cycles, 250#cycles, 500#cycles]; //amount of cycles until stations change their positions
	
	parameter var: width<-25; //25, 50, 100	
	parameter var: cell_width<- 2.0; //2.0, 1.0 , 0.5
	parameter "No. of transporters" category: "Transporter" var: no_transporter<-17 ; // 17, 4*17, 8*17
	parameter "No. of stations" category: "Stations" var: no_station<-4; //4, 4*4 (16), 4*4*4 (64)
	
	
	reflex save_results_explo {
    ask simulations {
    	
    	float mean_cyc_to_deliver <- ((self.total_delivered = 0) ? 0 : self.time_to_deliver_SUM/(self.total_delivered)); //
    	
    	save [int(self), self.seed, disturbance_cycles, self.cycle, self.total_delivered, mean_cyc_to_deliver] //..., ((total_delivered = 0) ? 0 : time_to_deliver_SUM/(total_delivered)) 
           to: "result_var/"+string(width)+"_gossip.csv" type: "csv" rewrite: false header: true; //rewrite: (int(self) = 0) ? true : false
    	}       
	}		
}
