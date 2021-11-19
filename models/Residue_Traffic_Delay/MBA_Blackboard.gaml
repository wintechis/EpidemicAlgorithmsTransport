/**
* Name: Blackboard Transporter
* Model_Based_VS_SRA_Stigmergy 
* Author: Sebastian Schmid
* Description: uses model-based agents with global, shared knowledge as a monolith 
* Tags: 
*/


@no_warning
model Blackboard_Transporter

import "../Station_Item.gaml"

global{
			
	//represents the monolithic knowledge about positions of already found or communicated stations. Entries have shape [rgb::location]
	//We don't use a second timestamp map with [rgb::int] here, as we can easily see if a disturbance occured when the position of a station changed
	map<rgb, point> station_position <- []; 
	
	init{						
			create transporter number: no_transporter;	
	}
	
	
	//every "disturbance_cycles" cycles, we evluate the residue (aka the percentage of agents that do NOT know the truth)
	reflex evaluate_residue when: (knowledge = true) and (cycle > 1) and every(disturbance_cycles-1){
		
		/*Residue is only evaluated against the global shared model as agents do not have local models.
		 * Still, residue can be != 0.0 if not _all_ changes have been detected by agents (although communication and sharin among agents is assumed to be instant!).
		 * It is assumed to be either 1.0 or 0.0 --> either all know everything or all only know a part of the truth 
		 */
		
		//TODO: would this "all or nothing" strategy not pledge for a more differentiated measure (á la "what percentage of truth is known??")
		
		float amt_suscpetible <- 0.0;
		
		//TODO: this checks for ALL entries in the model and does not differentiate
		//should we also consider "at least 1,2,3,...,N entries are correct"?	
		if(station_position != truth){
			amt_suscpetible <- 1.0;
		}
		
		//hence either 0 or 1 - all changes were detected (and communicated) or still knowledge missing
		add amt_suscpetible to: residue;
		
	}	
	
}


//##########################################################
//schedules agents, such that the simulation of their behaviour and the reflex evaluation is random and not always in the same order 
species scheduler schedules: shuffle(item+station+transporter);


species transporter parent: superclass schedules:[]{
	item load <- nil;
	
	float t_avg <- 0.0; //average time after an update injection where this agent noted a change or got a msg about one
	int updates <- 0; //received/noticed updates
	
	
	init{
		
	}
	
	//actively check surroundings for stations and note down perceived facts
	reflex check_surroundings_for_model when:(agents_inside(my_cell.neighbors) of_species station){
			
		station stat <-  first(agents_inside(my_cell.neighbors) of_species station); //gets the first station that is next to a transporter
		
		do add_knowledge(stat.location, stat.accept_color); //Adds a station to the tranporter's model, updates entries and checks for duplicates
				
	}
	
	//%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
	
		//No communication takes place here, but rather in the centralized fashion when sending an update to the blackboard 
			
	//%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
	
	
	//if i am empty or do not know where my item's station is -> wander
	reflex random_movement when:((load = nil) or !(station_position contains_key load.color)) {
		
		//generate a list of all my neighbor cells in a random order
		list<shop_floor> s <- shuffle(my_cell.neighbors); //get all cells with distance ONE
		
		loop cell over: s{ //check all cells in order if they are already taken.
			if(empty(transporter inside cell) and empty(station inside cell)) //as long as there is no other transporter or station
			{
				do take_a_step_to(cell); //if the cell is free - go there		
			}
		}
	}
	
	//if I transport an item and know its station, I will directly go to the nearest neighboring field of this station 
	reflex exact_movement when:((load != nil) and (station_position contains_key load.color)) {
		
		shop_floor target <- shop_floor(station_position at load.color); //YES, the target is the station itself, but we will not enter the stations cell. When we are next to it, our item will be loaded off, s.t. we won't enter the station 
		
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
		
		/*if am in the neighborhood of my target and there is NO station, delete global knowledge knowledge.*/
		if(target.neighbors contains my_cell)
		{
			// I am standing next to where I THINK my station should be. If so: in the next Reflex we deliver it automatically
			station s <- one_of(station inside target); //there should only be one station per cell, but this ensures that only one is picked.
		
			//if there is no station or it has the wrong color, my knowledge is WRONG
			if((s = nil) or (s.accept_color != load.color)) {
				
				do remove_knowledge(load.color); //remove wrong knowledge
				
				if(s != nil){
					do add_knowledge(s.location, s.accept_color); //nevertheless, if there is a station, update my knowledge
				}
			}	
		}
	}	
	
	//this reflex is for the case that I have a item and am now looking for a station. Up to now, i DO NOT have to queue
	reflex get_rid_of_item when: (load != nil){			
		//get the first cell with a station on it that is adjacent to me
		shop_floor cell_tmp <- (my_cell.neighbors) first_with (!(empty(station inside (each)))); //only ONE (the first cell...)
		list<shop_floor> cell_tmp_list <- (my_cell.neighbors) where (!(empty(station inside (each)))); //get all stations 
		 
		//check all adjacent cells with stations inside 
		loop cell over: cell_tmp_list{
			
			station s <- one_of(station inside cell); //there should only be one station per cell, but this ensures that only one is picked.
		
			//if the station we picked has the color of our item
			if(s.accept_color = load.color) {
				
				//if performance measure shall be evaluated
				/*Update all variables and containers for investigations*/
				if(performance = true){	
					put delivered[load.color]+1 key:load.color in: delivered; //count as delivered in respective color category
					total_delivered <- total_delivered +1; //increase counter for total amount of delivered items by 1
					
					//add current cycle to item to denote time when it was delivered
					load.cycle_delivered <- cycle; //sent new cycle as state to load
					int cycle_difference <- load.cycle_delivered - load.cycle_created; //calculate the cycle difference to add it to the evaluation variables in the next step
					time_to_deliver_SUM <- time_to_deliver_SUM + cycle_difference ; //add it to the total sum
					mean_of_delivered_cycles <- time_to_deliver_SUM/(total_delivered); //after successful delivery, update average amount of cycles
				}
				
				//if i did not know about this station before, add it to my model 
				if(!(station_position contains_key load.color)){
					do add_knowledge(s.location, load.color); // add/update knowledge about new station

				}
		
				do deliver_load(); //load is delivered
				
				break; //as we have loaded off our item, we do not need to check any leftover stations (also it would lead to an expection because load is now nil)
			}
		}		
	}
	
	//search adjacency for a station. If it has a item, pick it up. Depending in stigmergy settings, also initiate color marks
	reflex search_item when: load = nil{			
		//get the first cell with a station on it that is adjacent to me
		shop_floor cell_tmp <- (my_cell.neighbors) first_with (!(empty(station inside (each))));
		
		if(cell_tmp != nil) //if this cell is NOT empty, the transporter has a station neighbor
		{
			station s <- first(station inside cell_tmp); //cells can only have one station at a time, hence this list has exactly one entry. 'First' is sufficient to get it.
			
			//as I discovered a station, I add its position to my knowledge if i didn't know about it before 
			if(!(station_position contains_key s.accept_color)){
				do add_knowledge(s.location, s.accept_color); // add/update knowledge about new station  	
			}
						
			//Request state of s to ask about storage. if this NOT nil, a item has been created and is waiting there and assigned as load.
			load <- s.storage; //take over load from here 
			
			if( load != nil){
				
				//if load is NOT nil now, we took someitem over. If it would still be nil, then the station was simply empty
				s.storage <- nil; //we took the item, thus set station's storage to nil
				//Remark: here used to be an update for the load's location, but as the reflex for updating the item follows immediately after this reflex here, we don't need it
			}
			
		}		
	}
	
	reflex update_item when: (load != nil){
		ask load{
				my_cell <- myself.my_cell; //just ask the item you carry to go to the same spot as you.
				location <- myself.my_cell.location;
			}			
	}
	
	action update_delay{

		//for ALL transporters, as ALL receive the update at the exact same moment
		ask transporter{
			
			//increase sum of time until notice
			t_avg <- t_avg + (cycle - t_inj);
			//increase counter for received updates - 
			updates <- updates +1;
		}
	}
	
	action add_knowledge(point pt, rgb col){
		
		//if something changed, send an update to the blackboard
		if((station_position at col) != pt){
			add pt at:col to: station_position; // add/update knowledge about new station and assign a point to a color
			
			if(knowledge = true){
				do update_delay; //update the delay timer
				total_traffic <- total_traffic + 1; //increase the amount of traffic as an update was sent to the blackboard
				
				//TODO: we only consider the update for the noticing&sending agent here, but in reality it send it to the blackboard - and the BB broadcasts to all other.. which means aren't there really in total "no_transporter" msgs per update? 
		
			}
		}
	}
	
	action remove_knowledge(rgb col){
		remove key: col from: station_position; // remove knowledge about station 	
		
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
			
	aspect base{
		
		draw circle(cell_width) color: #grey border:#black;
	}
	
	aspect info{
		
		draw circle(cell_width) color: #grey border:#black;
		draw replace(name, "transporter", "") size: 10 at: location-(cell_width/2) color: #red;
	}
	
}

//##########################################################
experiment MBA_BB_No_Charts type:gui{
	parameter "Station placement distribution" category: "Simulation settings" var: selected_placement_mode among:placement_mode; //provides drop down list
		
	output {	
		layout #split;
		 display "Shop floor display" { 
				
		 		grid shop_floor lines: #black;
		 		species shop_floor aspect:info;
		 		species transporter aspect: info;
		 		species station aspect: base;
		 		species item aspect: base;	
		 }
		 
		  inspect "Knowledge" value: simulation attributes: ["station_position"] type:table;
		
	 }
	 
	
	
}

experiment MBA_BB type: gui {

	
	// Define parameters here if necessary
	parameter "No. of stations" category: "Stations" var: no_station;
	parameter "No. of transporters" category: "Transporter" var: no_transporter ;
	
	parameter "Station placement distribution" category: "Simulation settings" var: selected_placement_mode among:placement_mode; //provides drop down list
	parameter "Station placement parameter (only for strict mode)" category: "Simulation settings" var: strict_placement_factor; //provides drop down list
	
	parameter "Station colors" category: "Simulation settings" var: selected_color_mode among:color_mode; //provides drop down list
	
	
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
			
			
			chart "Mean cycles to deliver" type:series size:{1 ,0.5} position:{0, 0.25}{
					data "Mean of delivered cycles" value: mean_of_delivered_cycles color:#purple marker:false ;		
			}
			

	 }
	
	 display delivery_information refresh: every(20#cycles){
			 
			chart "total delivered items" type: series size: {1, 0.5} position: {0,0}{				
				data "total delivered items" value: total_delivered color:#red marker:false; 

			}
												 
			chart "Delivery distribution" type:histogram size:{1 ,0.5} position:{0, 0.5} {
					//datalist takes a list of keys and values from the "delivered" map  
					datalist delivered.keys value: delivered.values color:delivered.keys ;
			}
		}	
	}
  
}

/*Runs an amount of simulations in parallel, varies the the disturbance cycles*/
/*experiment MBA_BB_var_batch type: batch until: (cycle >= 5000) repeat: 20 autorun: true keep_seed: true{ 

	parameter "Disturbance cycles" category: "Simulation settings" var: disturbance_cycles among: [50#cycles, 100#cycles, 250#cycles, 500#cycles]; //amount of cycles until stations change their positions
	
	parameter var: width<-25; //25, 50, 100	
	parameter var: cell_width<- 2.0; //2.0, 1.0 , 0.5
	parameter "No. of transporters" category: "Transporter" var: no_transporter<-17 ; // 17, 4*17, 8*17
	parameter "No. of stations" category: "Stations" var: no_station<-4; //4, 4*4 (16), 4*4*4 (64)
	
	
	reflex save_results_explo {
    ask simulations {
    	
    	float mean_cyc_to_deliver <- ((self.total_delivered = 0) ? 0 : self.time_to_deliver_SUM/(self.total_delivered)); //
    	
    	ask self.transporter{
    		sum_traffic <- total_traffic + sum_traffic; //add up total amount of msgs
    	}
    	
    	float avg_traffic <- ((self.sum_traffic = 0) ? 0 : self.sum_traffic/(self.no_transporter)) ; // sum of msgs per transporter / amount transporters 
    	
    	save [int(self), self.seed, disturbance_cycles, self.cycle, avg_traffic, self.total_delivered, mean_cyc_to_deliver] //..., ((total_delivered = 0) ? 0 : time_to_deliver_SUM/(total_delivered)) 
           to: "result_var/"+ experiment.name +"_"+ string(width)+".csv" type: "csv" rewrite: false header: true; //rewrite: (int(self) = 0) ? true : false
    	}       
	}		
}*/

/*###########################################################*/
/*Runs an amount of simulations in parallel, varies the the disturbance cycles*/
experiment Performance type: batch until: (cycle >= 5000) repeat: 20 autorun: true keep_seed: true{ 

	parameter "Disturbance cycles" category: "Simulation settings" var: disturbance_cycles among: [50#cycles, 100#cycles, 250#cycles, 500#cycles]; //amount of cycles until stations change their positions
	
	parameter var: width<-50; //25, 50, 100	
	parameter var: cell_width<- 1.0; //2.0, 1.0 , 0.5
	parameter "No. of transporters" category: "Transporter" var: no_transporter<-4*17 ; // 17, 4*17, 8*17
	parameter "No. of stations" category: "Stations" var: no_station<-4*4; //4, 4*4 (16), 4*4*4 (64)
	
	
	parameter "Measure performance" category: "Measure" var: performance <- true;
	parameter "Measure knowledge" category: "Measure" var: knowledge <- false;
	
	
	reflex save_results_explo {
    ask simulations {
    	
    	float mean_cyc_to_deliver <- ((self.total_delivered = 0) ? 0 : self.time_to_deliver_SUM/(self.total_delivered)); //
    	
    	save [int(self), disturbance_cycles, self.cycle, self.total_delivered, mean_cyc_to_deliver]
           to: "simulation_results/performance/BB_"+ experiment.name +"_"+ string(width)+".csv" type: "csv" rewrite: false header: true; 
    	}       
	}		
}

/*Runs an amount of simulations in parallel, varies the the disturbance cycles*/
experiment Knowledge type: batch until: (cycle >= 5000) repeat: 20 autorun: true keep_seed: true{ 

	parameter "Disturbance cycles" category: "Simulation settings" var: disturbance_cycles among: [50#cycles, 100#cycles, 250#cycles, 500#cycles]; //amount of cycles until stations change their positions
	
	parameter var: width<-50; //25, 50, 100	
	parameter var: cell_width<- 1.0; //2.0, 1.0 , 0.5
	parameter "No. of transporters" category: "Transporter" var: no_transporter<-64 ; // 17, 64, 272
	parameter "No. of stations" category: "Stations" var: no_station<-16; //4, 16 (4*4), 64 (4*4*4)
	
	
	parameter "Measure performance" category: "Measure" var: performance <- false;
	parameter "Measure knowledge" category: "Measure" var: knowledge <- true;
	
	
	reflex save_results_explo {
    ask simulations {
    	
    	float avg_traffic <- float( self.total_traffic ) / self.no_transporter; //average amount of messages sent per transporter for whole simulation duration
    	
    	list<float> t_avgs <- [];
    	    	
    	//calculate average delay per update (only applicable if updates have been received (-> updates != 0))
    	ask self.transporter{
    		if(self.updates != 0)
    		{
    			add self.t_avg/self.updates to: t_avgs; //calculate every agents average time to receive or notice an update, then calc mean over all values
    		}		
    	}
    	
    	save [int(self), disturbance_cycles, self.cycle, mean(self.residue), avg_traffic, mean(t_avgs)]
           to: "simulation_results/knowledge/BB_"+ experiment.name +"_"+ string(width)+".csv" type: "csv" rewrite: false header: true; 
    	}       
	}		
}

