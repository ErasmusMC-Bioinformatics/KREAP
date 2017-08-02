# [](#header-1)Run KREAP Data Modeling

Select the "KREAP Data Modeling" tool from the right side in Galaxy.  
The "KREAP tool output" parameter must point to the output of the "KREAP Image Analysis" tool.  
The "index file" parameter must point to an associated index file.  
Click on Execute to run "KREAP Data Modeling":  
![use kreap data modeling 1](img/use_kreap_data_modeling1.png)  
  
A new dataset will be created in your history, which will hold the result of the "KREAP Data Modeling".  
The yellow color means that it's still working on something, you can click on the eye symbol to see the progress of the analysis:  
![use kreap data modeling 1](img/use_kreap_data_modeling2.png)  
  
At first sight, the result looks the same as the output from "KREAP Image Analysis", but when you scroll down you see the result "KREAP Data Modeling" has been added to the page.  
If one of the wells in a treatment couldn't be modeled, it will have an "Error!" status:  
![use kreap data modeling 1](img/use_kreap_data_modeling3.png)  

If you click on the "Click here for the results" link at the top of the result page you will be taken to a page that shows the results of modeling the wells:  
![use kreap data modeling 1](img/use_kreap_data_modeling4.png)  
  
The values are:  

| Column Name   | Description                                                       |
|---------------|-------------------------------------------------------------------|
| Treatment     | The treatment this well is part off                               |
| Well          | The well                                                          |
| Mu_m          | placeholder                                                       |
| StdErr_Mu_m   | placeholder                                                       |
| Lambda        | placeholder                                                       |
| StdErr_Lambda | placeholder                                                       |
| A             | placeholder                                                       |
| StdErr_A      | placeholder                                                       |
| RMSE          | placeholder                                                       |
| R2            | placeholder                                                       |
| Include       | Should this well be included in a the newly generated index file? |
  
Clicking on a well will show you the measured and modeled data in a graph:  
![use kreap data modeling 1](img/use_kreap_data_modeling5.png)  

Continue to the guide on how to deal with [errors in the modeling result](use_kreap_model_error).