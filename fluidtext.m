///--------- TTHyperLabelView.m

-(void)updateContainerAndBackground{
    
    if(![self readyToDisplay]){
        return;
    }
    
    self.container = [self containerFromBoxes:self.boxes
                               withHyperStyle:self.hyperStyle
                                      forSize:self.boxesView.frame.size];
    
    
    [self updateHyperBackgroundFrame];
}


///--------- TTHyperLabelView.m

-(TTHyperLabelContainer*)containerFromBoxes:(NSArray*)boxes
                             withHyperStyle:(TTHyperLayerStyle*)hyperStyle
                                    forSize:(CGSize)finalSize{
    
    // normalize the container size to a height of 1.0
    // calculate container aspect ratio
    CGSize containerNormalSize=CGSizeMake(finalSize.width/finalSize.height, 1);
    
    NSLog(@"finalSize %@",NSStringFromCGSize(finalSize));
    NSLog(@"normalized container %@",NSStringFromCGSize(containerNormalSize));
    
    
    float containerArea=containerNormalSize.width*containerNormalSize.height;
    NSLog(@"normalized container area %f",containerArea);
    
    
    // normalize all boxes size with a height of 1.0
    // then we add all the areas to find the ratio
    // between the normalized container and the boxes
    float boxesArea=0;
    for (TTHyperLabelBox *box in boxes){
        box.normalScale=1.0/box.originalSizeWithOverFlow.height;
        boxesArea+=box.normalizedSize.width * box.normalizedSize.height;
    }
    // Calculate exact area ratio
    float areaScale = sqrtf(containerArea/boxesArea);
    
    // Scale the normalized container with the all-boxes-container area ratio
    CGSize liquidContainer = containerNormalSize;
    liquidContainer.width*=1.0f/areaScale;
    liquidContainer.height*=1.0f/areaScale;
    
    /// Next step is to break the boxes into lines
    /// the resulting distribituion may produce
    /// a container that is larger than the requested
    /// this will be due to the area of the gaps between lines
    /// then we will resolve that overflow
    /// to compensate that with a wider container
    /// the final resulting conainer might be equal or less tall
    
    TTHyperLabelContainer *normalizedContainer;
    
    // Obtain an intial container
    // it is expected the resulting container
    // will have a proportion different to the requested
    normalizedContainer= [self normalizedContainerFromBoxes:boxes
                                         forLiquidContainer:liquidContainer];
    
    
    NSLog(@"test container : %@",NSStringFromCGSize(liquidContainer));
    NSLog(@"test linesFrame: %@",NSStringFromCGSize(normalizedContainer.contentSize));
    
    // Check the are of the resulting container
    // calculate the area difference between original and result
    // the difference is then aded to the width
    // this will cause the resulting container
    // to be always equal or less tall
    float fluidContainerArea =liquidContainer.width*liquidContainer.height;
    float contentArea=normalizedContainer.contentSize.width*normalizedContainer.contentSize.height;
    
    float difference =MAX(contentArea-fluidContainerArea,1.0);
    float overflow =difference/liquidContainer.height;
    
    liquidContainer.width+=overflow;
    
    normalizedContainer= [self normalizedContainerFromBoxes:boxes
                                         forLiquidContainer:liquidContainer];
    
    normalizedContainer.size=finalSize;
    
    //ALIGNMENT AND EFFECTS
    
    // For the fit paragraph mode
    // calculate the scale necessary to extend each line
    // such that it covers the full width
    // the result will cause the container to be expanded
    // this may cause the container to be taller than the requested
    if([hyperStyle.alignment isEqualToString:kHLAlignmentFit]){
        CGSize newContentSize=CGSizeZero;
        
        for(int l =0; l<normalizedContainer.lines.count; l ++){
            
            TTHyperLabelLine *line = [normalizedContainer.lines objectAtIndex:l];
            
            float scale =normalizedContainer.contentSize.width/line.size.width;
            CGSize newLineSize=CGSizeZero;
            
            
            for(int bx =0; bx<line.boxes.count; bx ++){
                TTHyperLabelBox *box = [line.boxes objectAtIndex:bx];
                box.normalScale*=scale;
                
                newLineSize.width += box.normalizedSizeNoOverFlow.width;
                newLineSize.height = MAX(newLineSize.height,box.normalizedSizeNoOverFlow.height);
            }
            
            line.size=newLineSize;
            newContentSize.width=MAX(newContentSize.width,line.size.width);
            newContentSize.height+=line.size.height;
            
        }
        normalizedContainer.contentSize=newContentSize;
    }
    
    // calculate the scale to compensate
    // the space normalization
    // we take the shortest scale
    // this guarantees the container will always fit
    // inside the requested size
    float contentScaleByWidth = finalSize.width/normalizedContainer.contentSize.width;
    float contentScaleByHeight = finalSize.height/normalizedContainer.contentSize.height;
    float contentScale=MIN(contentScaleByWidth,contentScaleByHeight);
    
    // we pass the content scale to the boxes and the container
    for(int i =0; i<normalizedContainer.boxes.count; i ++){
        TTHyperLabelBox *box =[normalizedContainer.boxes objectAtIndex:i];
        box.finalScale=contentScale;
    }
    normalizedContainer.contentFinalScale=contentScale;
    
    // finally we resolve how to center each line
    // this will compensate any gap caused
    // by the difference between the original and final aspect
    // and also apply the user paragraph alignment
    float verticalGap   =normalizedContainer.size.height- normalizedContainer.contentFinalSize.height;
    
    float ypos=0;
    for(int l =0; l<normalizedContainer.lines.count; l++){
        
        TTHyperLabelLine *line = [normalizedContainer.lines objectAtIndex:l];
        
        float alignmentGap =normalizedContainer.size.width- (line.size.width*normalizedContainer.contentFinalScale);
        
        if([hyperStyle.alignment isEqualToString:kHLAlignmentLeft]){
            
            alignmentGap=0;
        }
        if([hyperStyle.alignment isEqualToString:kHLAlignmentRight]){
            
            alignmentGap*=1;
        }
        if([hyperStyle.alignment isEqualToString:kHLAlignmentCenter]
           ||[hyperStyle.alignment isEqualToString:kHLAlignmentFit]){
            alignmentGap*=0.5;
        }
        
        float xpos=0;
        for(int bx =0; bx<line.boxes.count; bx ++){
            TTHyperLabelBox *box = [line.boxes objectAtIndex:bx];
            box.finalPosition=CGPointMake(xpos + alignmentGap, (ypos*normalizedContainer.contentFinalScale) +verticalGap/2);
            
            xpos+=box.finalSizeNoOverFlow.width;
        }
        
        ypos+=line.size.height;
        
    }
    
    
    return normalizedContainer;
    
}



-(TTHyperLabelContainer*)normalizedContainerFromBoxes:(NSArray*)boxes
                                   forLiquidContainer:(CGSize)liquidContainerSize{
    
    
    // CREATE A LINES CONTAINER AND START WITH A NEW LINE
    NSMutableArray *lines = [NSMutableArray new];
    TTHyperLabelLine *currentLine = [TTHyperLabelLine new];
    [lines addObject:currentLine];
    
    float currentLineWidth = 0;
    float currentLineHeight=0;
    
    /// IN THE CASE WE DON'T WANT TO BREAK LINES
    /// BUT FORCE TO STAY AS A SINGLE WORD
    __block BOOL isSingleWordGroup=YES;
    [boxes each:^(TTHyperLabelBox *box) {
        if(!box.singleLetter){
            isSingleWordGroup=NO;
        }
    }];
    
    /// ITERATE THROUGH ALL BOXES
    /// ADD THEM TO THE CURRENT LINE
    /// UNTIL THE WIDTH OVERPASSES THE CONTAINER
    /// THEN CREATE A NEW LINE
    for(int i =0; i<boxes.count; i ++){
        
        NSLog(@"-------------");
        
        TTHyperLabelBox *box = [boxes objectAtIndex:i];
        
        /// ABORT IF THE BOX IS A LINE BREK ITSELF
        if([box isLineBreak]){
            currentLineWidth  = 0;
            currentLineHeight = 0;
            
            currentLine=[TTHyperLabelLine new];
            [lines addObject:currentLine];
            continue;
        }
        
        /// OTHERWISE ADD TO THE CURRENT LINE
        [currentLine.boxes addObject:box];
        
        /// CALCULATE THE BOUNDS OF THE  LINE
        currentLineWidth+=box.normalizedSizeNoOverFlow.width;
        currentLineHeight=MAX(currentLineHeight,box.normalizedSizeNoOverFlow.height);
        if([self.hyperStyle.style isEqualToString:kHLTextStyleMarker]){
            currentLineHeight=MAX(currentLineHeight,box.normalizedSize.height);
            
        }
        NSLog(@"box %i currentLineWidth:%f containerW:%f",i,currentLineWidth,liquidContainerSize.width);
        currentLine.size =CGSizeMake(currentLineWidth, currentLineHeight);
        
        /// CHECK IF WE NEED TO ADD A NEW LINE
        if(i<boxes.count-1 && !isSingleWordGroup){
            
            TTHyperLabelBox *nextbox = [boxes objectAtIndex:i+1];
            float futureLineWidth=currentLineWidth+nextbox.normalizedSize.width;
            
            if(futureLineWidth > liquidContainerSize.width){
                NSLog(@"💥new line");
                
                currentLineWidth  = 0;
                currentLineHeight = 0;
                
                currentLine=[TTHyperLabelLine new];
                [lines addObject:currentLine];
            }
        }
    }
    
    float frameWidth=0;
    float frameHeight=0;
    
    // NORMALIZE ALL BOXES
    // BY ADDIND ONLY ONE SPACE CHARACTER BETWEEN THEM
    for(TTHyperLabelLine*line in lines){
        frameWidth=MAX(frameWidth,line.size.width);
        frameHeight+=line.size.height;
        
        [line.boxes eachWithIndex:^(TTHyperLabelBox *box, NSUInteger index) {
            box.word =[box.word stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
            //THIS METHOD ADDS A SPACE AFTER EACH LINE
            if(index<line.boxes.count-1 && !box.singleLetter){
                box.word=[NSString stringWithFormat:@"%@ ",box.word];
            }
        }];
        
    }
    
    ///CREATE THE RESULTING CONTAINER
    ///IT WILL NEVER BE WIDER THAN THE ORIGINAL
    ///BUT IT MAY BE TALLER
    TTHyperLabelContainer *result = [TTHyperLabelContainer new];
    result.lines=lines;
    result.boxes=boxes;
    result.contentSize=CGSizeMake(frameWidth, frameHeight);
    
    return result;
}