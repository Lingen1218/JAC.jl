    
    export perform

    """
    `Basics.perform(computation::Atomic.Computation)`  
        ... to perform the computation as prescribed by comp. All relevant intermediate and final results are printed to screen (stdout). 
            Nothing is returned.

    `Basics.perform(computation::Atomic.Computation; output=true)`  
        ... to perform the same but to return the complete output in a dictionary; the particular output depends on the type and 
            specifications of the computations but can easily accessed by the keys of this dictionary.
    """
    function Basics.perform(computation::Atomic.Computation; output::Bool=false)
        if  output    results = Dict{String, Any}()    else    results = nothing    end
        nModel = computation.nuclearModel

        # Distinguish between the computation of level energies and properties and the simulation of atomic processes
        if   length(computation.configs) != 0
            basis     = Basics.performSCF(computation.configs, nModel, computation.grid, computation.asfSettings)
            multiplet = Basics.performCI( basis, nModel, computation.grid, computation.asfSettings)
            LSjj.expandLevelsIntoLS(multiplet, computation.asfSettings.jjLS)
            #
            if output    results = Base.merge( results, Dict("multiplet:" => multiplet) ) 
                         results = Base.merge( results, Dict("grid:"      => computation.grid) )  end
            
            # Now compute all requested properties
            if  EinsteinX()        in computation.properties   
                outcome = Einstein.computeLines(multiplet,        computation.grid, computation.einsteinSettings)    
                if output    results = Base.merge( results, Dict("Einstein lines:" => outcome) )                  end
            end
            if  HFS()              in computation.properties       && computation.hfsSettings.calcIJFexpansion  
                outcome = Hfs.computeHyperfineMultiplet(multiplet, nModel, computation.grid, computation.hfsSettings)         
                if output    results = Base.merge( results, Dict("IJF multiplet:" => outcome) )                   end
            end
            if  HFS()              in computation.properties
                outcome = Hfs.computeOutcomes(multiplet, nModel,  computation.grid, computation.hfsSettings)         
                if output    results = Base.merge( results, Dict("HFS outcomes:" => outcome) )                    end
            end
            if  LandeJ()           in computation.properties   
                outcome = LandeZeeman.computeOutcomes(multiplet, nModel,  computation.grid, computation.zeemanSettings)      
                if output    results = Base.merge( results, Dict("Zeeman parameter outcomes:" => outcome) )       end
            end
            if  Isotope()          in computation.properties   
                outcome = IsotopeShift.computeOutcomes(multiplet, nModel, computation.grid, computation.isotopeSettings)         
                if output    results = Base.merge( results, Dict("Isotope parameter outcomes:" => outcome) )      end
            end
            if  AlphaX()           in computation.properties   
                outcome = AlphaVariation.computeOutcomes(multiplet, nModel, computation.grid, computation.alphaSettings)         
                if output    results = Base.merge( results, Dict("alpha variation parameter outcomes:" => outcome) )      end
            end
            if  FormF()            in computation.properties   
                outcome = FormFactor.computeOutcomes(multiplet, nModel, computation.grid, computation.formSettings)         
                if output    results = Base.merge( results, Dict("Form factor outcomes:" => outcome) )            end
            end
            if  Yields()           in computation.properties   
                outcome = DecayYield.computeOutcomes(computation.configs, computation.asfSettings, 
                                                        multiplet, nModel, computation.grid, computation.yieldSettings)     
                if output    results = Base.merge( results, Dict("Fluorescence and AutoIonization yield outcomes:" => outcome) )   end
            end
            if  Polarizibility()   in computation.properties   
                outcome = MultipolePolarizibility.computeOutcomes(multiplet, nModel, computation.grid, computation.polaritySettings)         
                if output    results = Base.merge( results, Dict("Polarizibility outcomes:" => outcome) )         end
            end
            if  Plasma()           in computation.properties   
                outcome = PlasmaShift.computeOutcomes(multiplet, nModel, computation.grid, computation.asfSettings, computation.plasmaSettings)         
                if output    results = Base.merge( results, Dict("Plasma shift outcomes:" => outcome) )            end
            end
        
        # Evaluate processes that need special SCF and CI procedures
        elseif  computation.process in [AugerInPlasma(), PhotoInPlasma()]
            pSettings        = computation.processSettings
            plasmaSettings   = PlasmaShift.Settings(pSettings.plasmaModel, pSettings.lambdaDebye, pSettings.ionSphereR0, pSettings.NoBoundElectrons)
            initialBasis     = Basics.performSCF(computation.initialConfigs, nModel, computation.grid, computation.initialAsfSettings)
            initialMultiplet = perform("computation: CI for plasma",  initialBasis, nModel, computation.grid, computation.initialAsfSettings, plasmaSettings)
            finalBasis       = Basics.performSCF(computation.finalConfigs, nModel, computation.grid, computation.finalAsfSettings)
            finalMultiplet   = perform("computation: CI for plasma",  finalBasis, nModel, computation.grid, computation.finalAsfSettings, plasmaSettings)
            #
            if      computation.process == AugerInPlasma()   
                outcome = AutoIonization.computeLinesPlasma(finalMultiplet, initialMultiplet, nModel, computation.grid, computation.processSettings) 
                if output    results = Base.merge( results, Dict("AutoIonization lines in plasma:" => outcome) )         end
            elseif  computation.process == PhotoInPlasma()  
                outcome = PhotoIonization.computeLinesPlasma(finalMultiplet, initialMultiplet, nModel, computation.grid, computation.processSettings) 
                if output    results = Base.merge( results, Dict("Photo lines in plasma:" => outcome) )                  end
            else
                error("stop a")
            end
            
        else
            initialBasis     = Basics.performSCF(computation.initialConfigs, nModel, computation.grid, computation.initialAsfSettings)
            initialMultiplet = Basics.performCI( initialBasis, nModel, computation.grid, computation.initialAsfSettings)
            finalBasis       = Basics.performSCF(computation.finalConfigs, nModel, computation.grid, computation.finalAsfSettings)
            finalMultiplet   = Basics.performCI(   finalBasis, nModel, computation.grid, computation.finalAsfSettings)
            #
            if computation.process in [PhotoExcFluor(), PhotoExcAuto(), PhotoIonFluor(), PhotoIonAuto(), ImpactExcAuto(), Dierec()]
                intermediateBasis     = Basics.performSCF(computation.intermediateConfigs, nModel, computation.grid, computation.intermediateAsfSettings)
                intermediateMultiplet = Basics.performCI( intermediateBasis, nModel, computation.grid, computation.intermediateAsfSettings)
            end
            #
            if      computation.process == Auger()   
                outcome = AutoIonization.computeLines(finalMultiplet, initialMultiplet, nModel, computation.grid, computation.processSettings) 
                if output    results = Base.merge( results, Dict("AutoIonization lines:" => outcome) )                  end
            elseif  computation.process == Compton()   
                outcome = RayleighCompton.computeLines(finalMultiplet, initialMultiplet, computation.grid, computation.processSettings) 
                if output    results = Base.merge( results, Dict("Rayleigh-Compton lines:" => outcome) )                end
            elseif  computation.process == DoubleAuger()   
                outcome = DoubleAutoIonization.computeLines(finalMultiplet, initialMultiplet, computation.grid, computation.processSettings) 
                if output    results = Base.merge( results, Dict("Double-Auger lines:" => outcome) )                    end
            elseif  computation.process == Dierec()  
                outcome = Dielectronic.computePathways(finalMultiplet, intermediateMultiplet, initialMultiplet, nModel, 
                                                                    computation.grid, computation.processSettings) 
                if output    results = Base.merge( results, Dict("dielectronic recombination pathways:" => outcome) )   end
            elseif  computation.process == MultiPhotonDE()
                outcome = MultiPhotonDeExcitation.computeLines(computation.processSettings.process,
                                                               finalMultiplet, initialMultiplet, computation.grid, computation.processSettings) 
                if output    results = Base.merge( results, Dict("multi-photon-de-excitation lines:" => outcome) )      end
            elseif  computation.process == Photo()   
                outcome = PhotoIonization.computeLines(finalMultiplet, initialMultiplet, nModel, computation.grid, computation.processSettings) 
                if output    results = Base.merge( results, Dict("photoionization lines:" => outcome) )                 end
            elseif  computation.process == PhotoDouble()   
                outcome = PhotoDoubleIonization.computeLines(finalMultiplet, initialMultiplet, computation.grid, computation.processSettings) 
                if output    results = Base.merge( results, Dict("Single-photon double-ionization lines:" => outcome) ) end
            elseif  computation.process == PhotoExc()
                outcome = PhotoExcitation.computeLines(finalMultiplet, initialMultiplet, computation.grid, computation.processSettings) 
                if output    results = Base.merge( results, Dict("photo-excitation lines:" => outcome) )                end
            elseif  computation.process == PhotoExcAuto()  
                outcome = PhotoExcitationAutoion.computePathways(finalMultiplet, intermediateMultiplet, initialMultiplet, nModel, 
                                                                 computation.grid, computation.processSettings) 
                if output    results = Base.merge( results, Dict("photo-excitation-autoionization pathways:" => outcome) )      end
            elseif  computation.process == PhotoExcFluor()
                outcome = PhotoExcitationFluores.computePathways(finalMultiplet, intermediateMultiplet, initialMultiplet, 
                                                                 computation.grid, computation.processSettings) 
                if output    results = Base.merge( results, Dict("photo-excitation-fluorescence pathways:" => outcome) )        end
            elseif  computation.process == Radiative() 
                outcome = PhotoEmission.computeLines(finalMultiplet, initialMultiplet, computation.grid, computation.processSettings) 
                if output    results = Base.merge( results, Dict("radiative lines:" => outcome) )                       end
            elseif  computation.process == RAuger()
                outcome = RadiativeAuger.computeLines(finalMultiplet, initialMultiplet, computation.grid, computation.processSettings) 
                if output    results = Base.merge( results, Dict("radiative Auger sharings:" => outcome) )              end
            elseif  computation.process == Rec()  
                outcome = PhotoRecombination.computeLines(finalMultiplet, initialMultiplet, nModel, computation.grid, computation.processSettings) 
                if output    results = Base.merge( results, Dict("photo recombination lines:" => outcome) )             end
                #
                #
            elseif  computation.process == Eimex()  
                outcome = ImpactExcitation.computeLines(finalMultiplet, initialMultiplet, nModel, computation.grid, computation.processSettings) 
                if output    results = Base.merge( results, Dict("impact-excitation lines:" => outcome) )               end
            elseif  computation.process == PairA1P()  
                outcome = PairAnnihilation1Photon.computeLines(finalMultiplet, initialMultiplet, computation.grid, computation.processSettings) 
                if output    results = Base.merge( results, Dict("pair-annihilation-1-photon lines:" => outcome) )       end
            elseif  computation.process == Coulex()
                outcome = CoulombExcitation.computeLines(finalMultiplet, initialMultiplet, computation.grid, computation.processSettings) 
                if output    results = Base.merge( results, Dict("Coulomb excitation lines:" => outcome) )               end
            elseif  computation.process == Coulion()
                outcome = CoulombIonization.computeLines(finalMultiplet, initialMultiplet, computation.grid, computation.processSettings) 
                if output    results = Base.merge( results, Dict("Coulomb ionization lines:" => outcome) )               end
            elseif  computation.process == PhotoIonAuto()   
                outcome = PhotoIonizationAutoion.computePathways(finalMultiplet, intermediateMultiplet, initialMultiplet, 
                                                                    computation.grid, computation.processSettings) 
                if output    results = Base.merge( results, Dict("photo-ionization-autoionization pathways:" => outcome) )      end
            elseif  computation.process == PhotoIonFluor()  
                outcome = PhotoIonizationFluores.computePathways(finalMultiplet, intermediateMultiplet, initialMultiplet, 
                                                                    computation.grid, computation.processSettings) 
                if output    results = Base.merge( results, Dict("photo-ionizatiton-fluorescence pathways:" => outcome) )        end
            elseif  computation.process == ImpactExcAuto()  
                outcome = ImpactExcitationAutoion.computePathways(finalMultiplet, intermediateMultiplet, initialMultiplet, 
                                                                    computation.grid, computation.processSettings) 
                if output    results = Base.merge( results, Dict("impact-excitation-autoionization pathways:" => outcome) )     end
            elseif  computation.process == MultiPI()   
                outcome = MultiPhotonIonization.computeLines(finalMultiplet, initialMultiplet, computation.grid, computation.processSettings) 
                if output    results = Base.merge( results, Dict("multi-photon single ionization:" => outcome) )        end
            elseif  computation.process == MultiPDI()   
                outcome = MultiPhotonDoubleIon.computeLines(finalMultiplet, initialMultiplet, computation.grid, computation.processSettings) 
                if output    results = Base.merge( results, Dict("multi-photon double ionization:" => outcome) )        end
            elseif  computation.process == InternalConv()   
                outcome = InternalConversion.computeLines(finalMultiplet, initialMultiplet, computation.grid, computation.processSettings) 
                if output    results = Base.merge( results, Dict("internal conversion lines:" => outcome) )        end
            else
                error("stop b")
            end
        end
        
        Defaults.warn(PrintWarnings())
        Defaults.warn(ResetWarnings())
        return( results )
    end



    """
    `Basics.perform(comp::Cascade.Computation)`  
        ... to set-up and perform a cascade computation that starts from a given set of initial configurations and proceeds via 
            various steps until a given number of electrons has been removed or the decay stops at some stable levels with regard 
            to the given atomic processes. The results of all individual steps are printed to screen but nothing is returned 
            otherwise.

    `Basics.perform(comp::Cascade.Computation; output::Bool=true, outputToFile::Bool=true)`   
        ... to perform the same but to return the complete output in a dictionary;  the particular output depends on the type 
            and specifications of the cascade but can easily accessed by the keys of this dictionary.
    """
    function Basics.perform(comp::Cascade.Computation; output::Bool=false, outputToFile::Bool=true)
        Cascade.perform(comp.scheme, comp::Cascade.Computation, output=output, outputToFile=outputToFile)
    end



    """
    `Basics.perform(comp::Cascade.Simulation)`  
        ... to set-up and perform a cascade computation that starts from a given set of initial configurations and proceeds via 
            various steps until a given number of electrons has been removed or the decay stops at some stable levels with regard 
            to the given atomic processes. The results of all individual steps are printed to screen but nothing is returned 
            otherwise.

    `Basics.perform(comp::Cascade.Simulation; output=true)`   
        ... to perform the same but to return the complete output in a dictionary;  the particular output depends on the type 
            and specifications of the cascade but can easily accessed by the keys of this dictionary.
    """
    function Basics.perform(comp::Cascade.Simulation; output::Bool=false)
        Cascade.perform(comp::Cascade.Simulation, output=output)
    end



    """
    `Basics.perform("computation: mutiplet from orbitals, no CI, CSF diagonal", configs::Array{Configuration,1}, 
                    initalOrbitals::Dict{Subshell, Orbital}, nuclearModel::Nuclear.Model, grid::Radial.Grid, settings::AsfSettings; printout::Bool=true)` 
        ... to generate from the given initial orbitals a multiplet of single-CSF levels by just using the diagonal 
            part of the Hamiltonian matrix; a multiplet::Multiplet is returned.  
    """
    function Basics.perform(sa::String, configs::Array{Configuration,1}, initalOrbitals::Dict{Subshell, Orbital}, nuclearModel::Nuclear.Model, 
                    grid::Radial.Grid, settings::AsfSettings; printout::Bool=true)
        !(sa == "computation: mutiplet from orbitals, no CI, CSF diagonal")   &&   error("Unsupported keystring = $sa")
        return( Basics.performCI(configs::Array{Configuration,1}, initalOrbitals::Dict{Subshell, Orbital}, nuclearModel::Nuclear.Model, 
                                 grid::Radial.Grid, settings::AsfSettings; printout=printout) )
    end


    """
    `Basics.perform("computation: CI for plasma", basis::Basis, nuclearModel::Nuclear.Model, grid::Radial.Grid, 
        settings::AsfSettings, plasmaSettings::PlasmaShift.Settings; printout::Bool=true)`  
        ... to  set-up and diagonalize from the given (SCF) basis the configuration-interaction matrix and to derive and
            display the level structure of the corresponding multiplet due to the given settings. Here, the CI matrix
            includes the modifications of the Hamiltonian due to the given plasmaSettings; a multiplet::Multiplet is returned.   
    """
    function Basics.perform(sa::String, basis::Basis, nuclearModel::Nuclear.Model, grid::Radial.Grid, 
                    settings::AsfSettings, plasmaSettings::PlasmaShift.Settings; printout::Bool=true)
        !(sa == "computation: CI for plasma")   &&   error("Unsupported keystring = $sa")
        return( Basics.performCI(basis::Basis, nuclearModel::Nuclear.Model, grid::Radial.Grid, 
                                 settings::AsfSettings, plasmaSettings::PlasmaShift.Settings; printout=printout) )
    end
                    


    """
    `Basics.performSCF(configs::Array{Configuration,1}, nuclearModel::Nuclear.Model, grid::Radial.Grid, settings::AsfSettings;
                       printout::Bool=true)`  
        ... to generate an atomic basis and to compute the self-consistent field (SCF) for this basis due to the given settings; 
            a basis::Basis is returned.  
    """
    function Basics.performSCF(configs::Array{Configuration,1}, nuclearModel::Nuclear.Model, grid::Radial.Grid, settings::AsfSettings;
                               printout::Bool=true)
        if  printout    println("\n... in performSCF ...")    end
        
        # Generate a list of relativistic configurations and determine an ordered list of subshells for these configurations
        relconfList = ConfigurationR[]
        for  conf in configs
            wa = Basics.generate("configuration list: relativistic", conf)
            append!( relconfList, wa)
        end
        if  printout    for  i = 1:length(relconfList)    println(">> include ", relconfList[i])    end   end
        subshellList = Basics.generate("subshells: ordered list for relativistic configurations", relconfList)
        Defaults.setDefaults("relativistic subshell list", subshellList; printout=printout)

        # Generate the relativistic CSF's for the given subshell list
        csfList = CsfR[]
        for  relconf in relconfList
            newCsfs = Basics.generate("CSF list: from single ConfigurationR", relconf, subshellList)
            append!( csfList, newCsfs)
        end

        # Determine the number of electrons and the list of coreSubshells
        NoElectrons      = sum( csfList[1].occupation )
        coreSubshellList = Subshell[]
        for  k in 1:length(subshellList)
            mocc = Basics.subshell_2j(subshellList[k]) + 1;    is_filled = true
            for  csf in csfList
                if  csf.occupation[k] != mocc    is_filled = false;    break   end
            end
            if   is_filled    push!( coreSubshellList, subshellList[k])    end
        end
            
        wa = Bsplines.generatePrimitives(grid)

        # Generate start orbitals
        if  typeof(settings.startScfFrom) == StartFromHydrogenic
            if  printout   println("Start SCF process with hydrogenic orbitals.")   end
            # Generate start orbitals for the SCF field by using B-splines
            ##x orbitals  = Bsplines.generateOrbitalsHydrogenic(waL, nsL, waS, nsS, nuclearModel, subshellList)
            orbitals  = Bsplines.generateOrbitalsHydrogenic(wa, nuclearModel, subshellList; printout=printout)
        elseif  typeof(settings.startScfFrom) == StartFromPrevious
            if  printout   println("Start SCF process from given list of orbitals.")    end
            # Taking starting orbitals for the given dictionary; non-relativistic orbitals with a proper nuclear charge
            # are adapted if no orbital is found
            orbitals = Dict{Subshell, Orbital}()
            for  subsh in subshellList
                if  haskey(settings.startScfFrom.orbitals, subsh)  
                    orb = settings.startScfFrom.orbitals[subsh]
                    orbitals = Base.merge( orbitals, Dict( subsh => orb) )
                else
                    println("Start orbitals do not contain an Orbital for subshell $subsh ")
                    orb      = HydrogenicIon.radialOrbital(subsh, nuclearModel.Z, grid)
                    orbitals = Base.merge( orbitals, Dict( subsh => orb) ) 
                end
            end
        else  error("stop a")
        end

        # Perform the SCF computations for the orbitals due to the given settings
        basis    = Basis(true, NoElectrons, subshellList, csfList, coreSubshellList, orbitals)
        if   settings.scField in [Basics.DFSField(), Basics.HSField()]
            basis = Bsplines.solveSelfConsistentMeanField(wa, nuclearModel, basis, settings; printout=printout) 
        elseif   settings.scField in [Basics.NuclearField()]  && settings.startScfFrom == StartFromHydrogenic() 
            # Return the basis as already generated.
        elseif   settings.scField in [Basics.ALField()] 
            basis = Bsplines.solveSelfConsistentALField(wa, nuclearModel, basis, settings; printout=printout)
        elseif   typeof(settings.scField) == Basics.EOLField 
            basis = Bsplines.solveSelfConsistentEOLField(wa, nuclearModel, basis, settings; printout=printout)
        else  error("stop b")
        end
        
        return( basis )  
    end
                    


    """
    `Basics.performSCF(basis::Basis, nuclearModel::Nuclear.Model, grid::Radial.Grid, frozenShells::Array{Shell,1}, 
                       settings::AtomicState.RasSettings; printout::Bool=true)`  
        ... to generate an atomic basis and to compute the self-consistent field (SCF) for this basis due to the given settings;
            all subshells due to the list of frozenShells are kept fixed. A newBasis::Basis is returned.  
    """
    function Basics.performSCF(basis::Basis, nuclearModel::Nuclear.Model, grid::Radial.Grid, frozenShells::Array{Shell,1}, 
                               settings::AtomicState.RasSettings; printout::Bool=true)
        if  printout    println("\n... in performSCF['for RAS step'] ...")    end
        
        # Determine the list of frozen subshells
        frozenSubshells = Subshell[]
        for  sh in frozenShells
            if  sh.l == 0    push!( frozenSubshells, Subshell(sh.n, -1))
            else             push!( frozenSubshells, Subshell(sh.n, sh.l));    push!( frozenSubshells, Subshell(sh.n, -sh.l -1))
            end
        end
        
        wa = Bsplines.generatePrimitives(grid)
        # Specify the AsfSettings for the given RAS step
        asfSettings = AsfSettings(true, CoulombInteraction(), Basics.DFSField(), StartFromHydrogenic(),    
                                  settings.maxIterationsScf, settings.accuracyScf, Subshell[], frozenSubshells, 
                                  CoulombInteraction(), NoneQed(), LSjjSettings(false), settings.levelSelectionCI ) 

        basis = Bsplines.solveSelfConsistentMeanField(wa, nuclearModel, basis, asfSettings; printout=printout) 
        
        return( basis )  
    end


    """
    `Basics.performCI(configs::Array{Configuration,1}, initalOrbitals::Dict{Subshell, Orbital}, nuclearModel::Nuclear.Model, 
                      grid::Radial.Grid, settings::AsfSettings; printout::Bool=true)` 
        ... to generate from the given initial orbitals a multiplet of single-CSF levels by just using the diagonal 
            part of the Hamiltonian matrix; a multiplet::Multiplet is returned.  
    """
    function Basics.performCI(configs::Array{Configuration,1}, initalOrbitals::Dict{Subshell, Orbital}, nuclearModel::Nuclear.Model, 
                              grid::Radial.Grid, settings::AsfSettings; printout::Bool=true)
        if  printout    println("\n... in perform['computation: mutiplet from orbitals, no CI, CSF diagonal'] ...")    end
        
        # Generate a list of relativistic configurations and determine an ordered list of subshells for these configurations
        relconfList = ConfigurationR[]
        for  conf in configs
            wa = Basics.generate("configuration list: relativistic", conf)
            append!( relconfList, wa)
        end
        if  printout    for  i = 1:length(relconfList)    println(">> include ", relconfList[i])    end   end
        subshellList = Basics.generate("subshells: ordered list for relativistic configurations", relconfList)
        Defaults.setDefaults("relativistic subshell list", subshellList; printout=printout)

        # Generate the relativistic CSF's for the given subshell list
        csfList = CsfR[]
        for  relconf in relconfList
            newCsfs = Basics.generate("CSF list: from single ConfigurationR", relconf, subshellList)
            append!( csfList, newCsfs)
        end

        # Determine the number of electrons and the list of coreSubshells
        NoElectrons      = sum( csfList[1].occupation )
        coreSubshellList = Subshell[]
        for  k in 1:length(subshellList)
            mocc = Basics.subshell_2j(subshellList[k]) + 1;    is_filled = true
            for  csf in csfList
                if  csf.occupation[k] != mocc    is_filled = false;    break   end
            end
            if   is_filled    push!( coreSubshellList, subshellList[k])    end
        end
        
        # Set-up a basis for calculating the Hamiltonian matrix
        basis = Basis(true, NoElectrons, subshellList, csfList, coreSubshellList, initalOrbitals)
    
        # Calculate the diagonal part of the Hamiltonian matrix and define a multiplet for these approximate ASf;
        # Generate first an effective nuclear charge Z(r) on the given grid
        potential = Nuclear.nuclearPotential(nuclearModel, grid)
        
        keep = true
        InteractionStrength.XL_Coulomb_reset_storage(keep)
        #
        n = length(csfList);    matrix = zeros(Float64, n, n)
        for  r = 1:n
            wa = compute("angular coefficients: e-e, Ratip2013", basis.csfs[r], basis.csfs[r])
            me = 0.
            for  coeff in wa[1]
                jj = Basics.subshell_2j(basis.orbitals[coeff.a].subshell)
                me = me + coeff.T * sqrt( jj + 1) * RadialIntegrals.GrantIab(basis.orbitals[coeff.a], basis.orbitals[coeff.b], grid, potential)
            end

            for  coeff in wa[2]
                if  settings.eeInteractionCI in [CoulombInteraction(), CoulombBreit()]
                    me = me + coeff.V * InteractionStrength.XL_Coulomb(coeff.nu, basis.orbitals[coeff.a], basis.orbitals[coeff.b],
                                                                                     basis.orbitals[coeff.c], basis.orbitals[coeff.d], grid, keep=keep)   end
                if  settings.eeInteractionCI in [BreitInteraction(), CoulombBreit()]
                    me = me + coeff.V * InteractionStrength.XL_Breit(coeff.nu, basis.orbitals[coeff.a], basis.orbitals[coeff.b],
                                                                                   basis.orbitals[coeff.c], basis.orbitals[coeff.d], grid)     end
            end
            matrix[r,r] = me
        end 
        #
        eigen  = Basics.diagonalize("matrix: LinearAlgebra", matrix)
        levels = Level[]
        for  ev = 1:length(eigen.values)
            vector = eigen.vectors[ev];   ns = 0
            for  r = 1:length(vector)   
                if      (vector[r])^2 > 0.99    ns = r;   break    
                elseif  (vector[r])^2 > 0.01    error("stop a; unexpected mixing coefficieint; vector = $vector ")    
                end
            end
            J = csfList[ns].J
            newlevel = Level( J, AngularM64(J.num//J.den), csfList[ns].parity, 0, eigen.values[ev], 0., true, basis, vector ) 
            push!( levels, newlevel)
        end
        mp = Multiplet("noName", levels)
        mp = Basics.sortByEnergy(mp)
        
        levelNos = Int64[]
        for (ilev, level) in  enumerate(mp.levels)       push!(levelNos, ilev)   end
        
        # Display all level energies and energy splittings
        if  printout
            Basics.tabulate(stdout, "multiplet: energies", mp, levelNos)
            Basics.tabulate(stdout, "multiplet: energy relative to immediately lower level",    mp, levelNos)
            Basics.tabulate(stdout, "multiplet: energy of each level relative to lowest level", mp, levelNos)
        end
        printSummary, iostream = Defaults.getDefaults("summary flag/stream")
        if  printSummary     
            Basics.tabulate(iostream, "multiplet: energies", mp, levelNos)
            Basics.tabulate(iostream, "multiplet: energy relative to immediately lower level",    mp, levelNos)
            Basics.tabulate(iostream, "multiplet: energy of each level relative to lowest level", mp, levelNos)
        end
    
        return( mp )
    end
    

    """
    `Basics.performCI(basis::Basis, nuclearModel::Nuclear.Model, grid::Radial.Grid, settings::AsfSettings; printout::Bool=true)`  
        ... to  set-up and diagonalize from the (SCF) basis the configuration-interaction matrix and to derive and display the 
            level structure of the corresponding multiplet due to the given settings; a multiplet::Multiplet is returned.   
    """
    function Basics.performCI(basis::Basis, nuclearModel::Nuclear.Model, grid::Radial.Grid, settings::AsfSettings; printout::Bool=true)
        
        # Determine the J^P symmetry blocks
        symmetries = Dict{LevelSymmetry,Int64}()
        for  csf in basis.csfs
            sym = LevelSymmetry(csf.J, csf.parity)
            if     haskey(symmetries, sym)    symmetries[sym] = symmetries[sym] + 1
            else   symmetries = Base.merge( symmetries, Dict( sym => 1 ) )
            end
        end

        # Test the total number of CSF
        NoCsf = 0
        for (sym,v) in symmetries   NoCsf = NoCsf + v   end
    
        # Calculate for each symmetry block the corresponding CI matrix, diagonalize it and append a Multiplet for this block
        multiplets = Multiplet[]
        for  (sym,v) in  symmetries
            # Skip the symmetry block if it not selected
            @show  sym, settings.levelSelectionCI,  Basics.selectSymmetry(sym, settings.levelSelectionCI)
            if  !Basics.selectSymmetry(sym, settings.levelSelectionCI)     continue    end
            matrix = compute("matrix: CI, J^P symmetry", sym, basis, nuclearModel, grid, settings; printout=printout)
            eigen  = Basics.diagonalize("matrix: LinearAlgebra", matrix)
            ##x eigen  = Basics.diagonalize("matrix: Julia, eigfact", matrix)
            levels = Level[]
            for  ev = 1:length(eigen.values)
                # Construct the eigenvector with regard to the given basis (not w.r.t the symmetry block)
                evSym = eigen.vectors[ev];    vector = zeros( length(basis.csfs) );   ns = 0
                for  r = 1:length(basis.csfs) 
                    if LevelSymmetry(basis.csfs[r].J, basis.csfs[r].parity) == sym    ns = ns + 1;   vector[r] = evSym[ns]   end
                end
                newlevel = Level( sym.J, AngularM64(sym.J.num//sym.J.den), sym.parity, 0, eigen.values[ev], 0., true, basis, vector ) 
                push!( levels, newlevel)
            end
            wa = Multiplet("noName", levels)
            push!( multiplets, wa)
        end
        
        # Merge all multiplets into a single one
        mp = Basics.merge(multiplets)
        mp = Basics.sortByEnergy(mp)
        
        # Determine the level list to be printed out
        levelNos = Int64[]
        for (ilev, level) in  enumerate(mp.levels)
            if  Basics.selectLevel(level, settings.levelSelectionCI)    push!(levelNos, ilev)    end
        end
        
        # Display all level energies and energy splittings
        if  printout
            Basics.tabulate(stdout, "multiplet: energies", mp, levelNos)
            Basics.tabulate(stdout, "multiplet: energy relative to immediately lower level",    mp, levelNos)
            Basics.tabulate(stdout, "multiplet: energy of each level relative to lowest level", mp, levelNos)
        end
        printSummary, iostream = Defaults.getDefaults("summary flag/stream")
        if  printSummary     
            Basics.tabulate(iostream, "multiplet: energies", mp, levelNos)
            Basics.tabulate(iostream, "multiplet: energy relative to immediately lower level",    mp, levelNos)
            Basics.tabulate(iostream, "multiplet: energy of each level relative to lowest level", mp, levelNos)
        end
    
        return( mp )
    end
    

    """
    `Basics.performCI(basis::Basis, nuclearModel::Nuclear.Model, grid::Radial.Grid, settings::AsfSettings, 
                      plasmaSettings::PlasmaShift.Settings; printout::Bool=true)`  
        ... to  set-up and diagonalize from the given (SCF) basis the configuration-interaction matrix and to derive and
            display the level structure of the corresponding multiplet due to the given settings. Here, the CI matrix
            includes the modifications of the Hamiltonian due to the given plasmaSettings; a multiplet::Multiplet is returned.   
    """
    function Basics.performCI(basis::Basis, nuclearModel::Nuclear.Model, grid::Radial.Grid, 
                              settings::AsfSettings, plasmaSettings::PlasmaShift.Settings; printout::Bool=true)
        
        # Determine the J^P symmetry blocks
        symmetries = Dict{LevelSymmetry,Int64}()
        for  csf in basis.csfs
            sym = LevelSymmetry(csf.J, csf.parity)
            if     haskey(symmetries, sym)    symmetries[sym] = symmetries[sym] + 1
            else   symmetries = Base.merge( symmetries, Dict( sym => 1 ) )
            end
        end

        # Test the total number of CSF
        NoCsf = 0
        for (sym,v) in symmetries   NoCsf = NoCsf + v   end
    
        # Calculate for each symmetry block the corresponding CI matrix for the given plasma model and parameters as specified by
        # plasmaSettings, diagonalize it and append a Multiplet for this block
        multiplets = Multiplet[]
        for  (sym,v) in  symmetries
            matrix = compute("matrix: CI for plasma, J^P symmetry", sym, basis, nuclearModel, grid, settings, plasmaSettings; printout=printout)
            eigen  = Basics.diagonalize("matrix: LinearAlgebra", matrix)
            levels = Level[]
            for  ev = 1:length(eigen.values)
                # Construct the eigenvector with regard to the given basis (not w.r.t the symmetry block)
                evSym = eigen.vectors[ev];    vector = zeros( length(basis.csfs) );   ns = 0
                for  r = 1:length(basis.csfs) 
                    if LevelSymmetry(basis.csfs[r].J, basis.csfs[r].parity) == sym    ns = ns + 1;   vector[r] = evSym[ns]   end
                end
                newlevel = Level( sym.J, AngularM64(sym.J.num//sym.J.den), sym.parity, 0, eigen.values[ev], 0., true, basis, vector ) 
                push!( levels, newlevel)
            end
            wa = Multiplet("noName", levels)
            push!( multiplets, wa)
        end
        
        # Merge all multiplets into a single one
        mp = Basics.merge(multiplets)
        mp = Basics.sortByEnergy(mp)
        
        levelNos = Int64[]
        for (ilev, level) in  enumerate(mp.levels)       push!(levelNos, ilev)   end
        
        # Display all level energies and energy splittings
        if  printout
            Basics.tabulate(stdout, "multiplet: energies", mp, levelNos)
            Basics.tabulate(stdout, "multiplet: energy relative to immediately lower level",    mp, levelNos)
            Basics.tabulate(stdout, "multiplet: energy of each level relative to lowest level", mp, levelNos)
        end
        printSummary, iostream = Defaults.getDefaults("summary flag/stream")
        if  printSummary     
            Basics.tabulate(iostream, "multiplet: energies", mp, levelNos)
            Basics.tabulate(iostream, "multiplet: energy relative to immediately lower level",    mp, levelNos)
            Basics.tabulate(iostream, "multiplet: energy of each level relative to lowest level", mp, levelNos)
        end
    
        return( mp )
    end
