function Set-OBSRenderDelayFilter
{
    <#
    .SYNOPSIS
        Sets a RenderDelay filter.
    .DESCRIPTION
        Adds or Changes a RenderDelay Filter on an OBS Input.

        This changes the RenderDelay of an image.
    .EXAMPLE
        Show-OBS -Uri https://pssvg.start-automating.com/Examples/Stars.svg |
            Set-OBSRenderDelayFilter -RenderDelay .75
    #>
    [inherit(Command={
        Import-Module ..\..\obs-powershell.psd1 -Global
        "Add-OBSSourceFilter"
    }, Dynamic, Abstract, ExcludeParameter='FilterKind','FilterSettings')]
    [Alias('Add-OBSRenderDelayFilter')]    
    param(
    # The RenderDelay.
    [Parameter(ValueFromPipelineByPropertyName)]
    [timespan]
    $RenderDelay,    

    # If set, will remove a filter if one already exists.
    # If this is not provided and the filter already exists, the settings of the filter will be changed.
    [switch]
    $Force
    )
    
    process {
        $myParameters = [Ordered]@{} + $PSBoundParameters
        
        if (-not $myParameters["FilterName"]) {
            $filterName = $myParameters["FilterName"] = "RenderDelay"
        }
                
                
        $myParameterData = [Ordered]@{
            delay_ms = if ($RenderDelay.Ticks -lt 10kb) {
                [int]$RenderDelay.Ticks
            } else {
                [int]$RenderDelay.TotalMilliseconds
            }
        }
        $addSplat = @{            
            filterName = $myParameters["FilterName"]
            SourceName = $myParameters["SourceName"]
            filterKind = "gpu_delay"
            filterSettings = $myParameterData
        }
        
        if ($MyParameters["PassThru"]) {
            $addSplat.Passthru = $MyParameters["PassThru"]
            if ($MyInvocation.InvocationName -like 'Add-*') {
                Add-OBSSourceFilter @addSplat
            } else {
                $addSplat.Remove('FilterKind')
                Set-OBSSourceFilterSettings @addSplat
            }
            return            
        }

        # Add the input.
        $outputAddedResult = Add-OBSSourceFilter @addSplat *>&1

        # If we got back an error
        if ($outputAddedResult -is [Management.Automation.ErrorRecord]) {
            # and that error was saying the source already exists, 
            if ($outputAddedResult.TargetObject.d.requestStatus.code -eq 601) {
                # then check if we use the -Force.
                if ($Force)  { # If we do, remove the input                    
                    Remove-OBSSourceFilter -FilterName $addSplat.FilterName -SourceName $addSplat.SourceName
                    # and re-add our result.
                    $outputAddedResult = Add-OBSInput @addSplat *>&1
                } else {
                    # Otherwise, get the existing filter.
                    $existingFilter = Get-OBSSourceFilter -SourceName $addSplat.SourceName -FilterName $addSplat.FilterName
                    # then apply the settings
                    $existingFilter.Set($addSplat.filterSettings)
                    # and output them
                    $existingFilter
                    # (don't forget to null the result, so we don't show this error)
                    $outputAddedResult = $null
                }
            }

            # If the output was still an error
            if ($outputAddedResult -is [Management.Automation.ErrorRecord]) {
                # use $psCmdlet.WriteError so that it shows the error correctly.
                $psCmdlet.WriteError($outputAddedResult)
            }
            
        }
        # Otherwise, if we had a result
        elseif ($outputAddedResult) {
            # Otherwise, get the input from the filters.
            Get-OBSSourceFilter -SourceName $addSplat.SourceName -FilterName $addSplat.FilterName
                
        }
    }
}
